# Snowflake
## Motivation
* Traditional data warehouses struggle in the cloud
  * Designed for fixed resources (can't leverage cloud elasticity)
  * Depend on complex ETL pipelines and physical tuning
  * Poor fit for semi-structured data (JSON, XML, Avro)
* Big Data platforms (Hadoop, Spark) lack:
  * Efficiency and features of established data warehousing
  * Require significant engineering effort to use

## Goals (Enterprise-ready cloud data warehouse)
* Pure SaaS experience (no tuning, no physical design)
* Full SQL support with ACID transactions
* Semi-structured data support (schema-less, JSON, Avro)
* Elastic scaling (storage and compute independently)
* High availability (tolerate node/cluster/data center failures)
* Cost-efficient (pay only for what you use)
* Secure (end-to-end encryption)

## Key Design Choice: Storage vs Compute Separation

### Problems with Shared-Nothing in Cloud
* **Heterogeneous Workload**
  * Bulk loading (high I/O, light compute) vs complex queries (low I/O, heavy compute)
  * Fixed hardware configuration = poor average utilization
* **Membership Changes**
  * Node failures or resizing requires data reshuffling
  * Performance impact limits elasticity and availability
* **Online Upgrade**
  * Software/hardware upgrades must touch every node
  * Hard to implement without downtime in tightly-coupled system

### Snowflake's Solution
* Separate storage and compute
* Storage: Amazon S3 (or any blob store)
* Compute: Snowflake's shared-nothing engine
* Local disk for caching (not for replication)
  * Cache hot data only
  * Performance approaches/exceeds pure shared-nothing when caches warm
* Novel architecture: **multi-cluster, shared-data**

## Architecture (Three Layers)

### 1. Data Storage Layer
* Uses Amazon S3 for table data and query results
* Why S3?
  * High availability, strong durability (99.999999999%)
  * Usability hard to beat
  * No need to build custom storage service
* S3 characteristics affect design:
  * Higher latency than local storage
  * Blob store with PUT/GET/DELETE interface
  * Can only overwrite files in full (no appends)
  * Supports GET requests for file ranges
* **File format**: Hybrid columnar (PAX)
  * Tables horizontally partitioned into large immutable files (64MB+)
  * Within each file: values of each column grouped together and compressed
  * File header contains column offsets
  * Queries download only needed columns
* S3 also used for:
  * Temp data (when local disk exhausted)
  * Large query results
* Metadata stored in transactional key-value store (Cloud Services layer)

### 2. Virtual Warehouses (VWs)
* Clusters of EC2 instances
* Presented as abstract "T-shirt sizes" (X-Small to XX-Large)
  * Users don't see individual worker nodes
* **Elasticity and Isolation**
  * Pure compute resources (can create/destroy/resize on demand)
  * Creating/destroying VW has no effect on database state
  * Each query runs on exactly one VW
  * Worker nodes not shared across VWs (strong performance isolation)
  * Users can have multiple VWs running simultaneously
  * All VWs access same shared storage (no data copying needed)
* **Worker Processes**
  * Each worker node spawns new process per query
  * Process lives only for query duration
  * Failures easily contained (retry query)
* **Local Caching and File Stealing**
  * Each worker node caches table files on local disk
  * Cache shared among concurrent/subsequent queries
  * LRU replacement policy
  * Consistent hashing assigns files to nodes (improves hit rate)
  * Lazy consistent hashing (no immediate reshuffling on membership changes)
  * File stealing: slow nodes can request help from faster peers
* **Execution Engine**
  * Columnar: better CPU cache/SIMD usage, compression
  * Vectorized: pipeline batches of thousands of rows (no materialization)
  * Push-based: operators push results downstream (better cache efficiency)

### 3. Cloud Services Layer
* Multi-tenant, long-lived services (shared across users)
* Services: access control, query optimizer, transaction manager, metadata
* Replicated for high availability and scalability
* **Query Management and Optimization**
  * Cascades-style, top-down cost-based optimization
  * No indices, so smaller plan search space
  * Postpone decisions to execution time (e.g., data distribution for joins)
  * Tracks query state for performance counters and failure detection
* **Concurrency Control**
  * ACID transactions via Snapshot Isolation (SI)
  * SI on top of Multi-Version Concurrency Control (MVCC)
  * Natural fit: table files are immutable (due to S3)
  * Write operations create new table version by adding/removing files
  * File additions/removals tracked in metadata
* **Pruning (instead of indices)**
  * Min-max based pruning (zone maps, small materialized aggregates)
  * Maintains min/max values for each table file
  * Works for relational columns AND paths in semi-structured data
  * Pruning for complex expressions (e.g., `WEEKDAY(orderdate) IN (6,7)`)
  * Dynamic pruning: hash join statistics pushed to probe side
  * Bloom filters over paths in semi-structured data

## Feature Highlights

### Pure SaaS Experience
* Web UI accessible from any browser (no software download needed)
* Users can point at cloud data and query immediately
* No tuning knobs, no physical design, no storage grooming
* Only one tuning parameter: how much performance you want

### Continuous Availability

#### Fault Resilience
* **Data Storage**: S3 replicated across availability zones (AZs)
* **Metadata**: distributed across multiple AZs
* **Cloud Services**: stateless nodes in multiple AZs with load balancer
  * Single node/AZ failure causes no system-wide impact
* **Virtual Warehouses**: not distributed across AZs (for performance)
  * Worker node failure: query fails, transparently re-executed
  * Standby node pool for fast replacement
  * Full AZ failure: user must re-provision VW (rare event)

#### Online Upgrade
* Multiple versions of services run side-by-side
* Services are stateless (hard state in transactional KV store)
* Metadata versioning and schema evolution
* Upgrade process:
  1. Deploy new version alongside old version
  2. Progressively switch user accounts to new version
  3. Queries on old version run to completion
  4. Terminate old version when all users migrated
* Different VW versions can share same worker nodes and caches
* No downtime, no performance degradation
* Weekly upgrades in production
* Can quickly downgrade if critical bugs found

### Semi-Structured Data

#### VARIANT Type
* Three new SQL types: VARIANT, ARRAY, OBJECT
* VARIANT stores:
  * Any native SQL type (DATE, VARCHAR, etc.)
  * Variable-length ARRAYs
  * JavaScript-like OBJECTs (maps from strings to VARIANT values)
* Self-describing, compact binary serialization
* Can be used as join keys, grouping keys, ordering keys

#### ELT vs ETL
* "Schema later" approach
* Load JSON/Avro/XML directly into VARIANT column
* No schema specification required
* Schema evolution decoupled from producers/consumers
* Transform using full SQL power after loading

#### Post-relational Operations
* Extraction: by field name (OBJECT) or offset (ARRAY)
  * Functional SQL notation or JavaScript-like path syntax
* Flattening: SQL lateral views (can be recursive)
* Aggregation: ARRAY_AGG, OBJECT_AGG functions

#### Columnar Storage for Semi-Structured Data
* Automatic statistical analysis of documents per table file
* Automatic type inference
* Frequently common typed paths extracted and stored separately
* Same compressed columnar format as relational data
* Pruning metadata computed for extracted columns
* Projection pushdown: access only needed columns
* Bloom filters over paths (for pruning)

#### Optimistic Conversion
* Converts strings to native types (dates, numbers) at write time
* Preserves both converted result and original string
* Allows pruning on dates
* Minimal performance impact (unused columns not loaded)

#### Performance
* TPC-H experiments (SF100, SF1000)
* Schema-less (single VARIANT column) vs relational schema
* ~10% overhead for most queries
* Benefits of columnar storage, execution, and pruning without user effort

### Time Travel and Cloning

#### Time Travel
* File retention (up to 90 days) enables reading earlier versions
```sql
SELECT * FROM my_table AT(TIMESTAMP => '2015-05-01 16:20:00');
SELECT * FROM my_table AT(OFFSET => -60*5); -- 5 min ago
SELECT * FROM my_table BEFORE(STATEMENT => '8e5d0ca9-...');
```
* Can join different versions in same query
```sql
SELECT new.key, new.value, old.value FROM my_table new
JOIN my_table AT(OFFSET => -86400) old -- 1 day ago
ON new.key = old.key WHERE new.value <> old.value;
```

#### UNDROP
* Quickly restore accidentally dropped tables/schemas/databases
```sql
DROP DATABASE important_db; -- whoops!
UNDROP DATABASE important_db;
```

#### CLONE
* Create copy of table/schema/database without physical file copying
* Only copies metadata
* Both tables initially refer to same files
* Can be modified independently thereafter
* Can combine with AT/BEFORE for after-the-fact snapshots
```sql
CREATE DATABASE recovered_db CLONE important_db
  BEFORE(STATEMENT => '8e5d0ca9-...');
```

### Security

#### Key Hierarchy (4 levels)
```
Root Keys (AWS CloudHSM)
  ↓
Account Keys (one per user account)
  ↓
Table Keys (one per table)
  ↓
File Keys (one per file, derived from table key + filename)
```
* Hierarchical model constrains data protected by each key
* Multi-tenancy isolation: separate account key per user

#### Key Life Cycle
* **Key Rotation**: create new versions periodically (e.g., monthly)
  * Retired versions used only to decrypt (not encrypt)
* **Rekeying**: re-encrypt old data with new keys (e.g., yearly)
  * Allows retired keys to be destroyed
* File keys cryptographically derived (not stored separately)
  * Table key + filename → file key
  * Avoids managing billions of file keys
* Re-encryption uses separate workers (no impact on queries)
* Atomic metadata update after rekeying

#### End-to-End Encryption
* AWS CloudHSM for root keys (tamper-proof)
  * Root keys never leave HSM devices
  * All root key operations performed in HSM
* All data encrypted before:
  * Sent over network
  * Written to local disk
  * Written to S3
* Additional protections:
  * Isolation via S3 access policies
  * Role-based access control (RBAC)
  * Encrypted import/export (Amazon never sees plaintext)
  * Two-factor authentication

## Real-World Use Cases

### Financial Services

#### Capital One (Banking & Credit Cards)
* Began migrating all data to Snowflake in 2017
* **Scale**: Enables 6,000+ analysts to run millions of queries
* **Performance**: Runs 250 concurrent queries (vs 60 on Teradata)
* **Use cases**:
  * Data-driven innovation
  * ML model training
  * Compliance and governance
  * Cost visibility and optimization
* **Benefit**: No performance degradation, instant scaling, lower cost

#### Block/Square (Payments)
* Built self-service fraud prevention models
* Analysts identify bad actors and detect attack vectors
* Real-time fraud detection on transaction data

#### Citi (Banking)
* Satisfies regulatory compliance requirements
* Financial crime detection (KYC, AML)
* Unifies data across business for anomaly detection

### Technology & SaaS

#### Adobe (Creative Software)
* High-profile Snowflake customer
* Uses Snowflake for data storage and analysis

#### DoorDash (Food Delivery)
* Became customer in 2018, migrated data in early 2019
* **Performance**: 2x faster data requests at 50% cost
* Handles high-volume transaction and delivery data

#### Netflix (Streaming Media)
* Multi-platform data warehouse approach
* Uses Snowflake alongside S3/Hive, Redshift, Druid, MySQL
* Metacat service provides unified view across platforms
* **Use cases**:
  * Data movement (Hive → Snowflake)
  * Spark compute engine with lineage tracking
  * Federated architecture for complex data needs

### Retail & E-commerce

#### Sainsbury's (Grocery Retail)
* Real-time transaction and click-stream processing
* Uses Snowflake Streams and Tasks for continuous data pipelines

#### S-Group & Kesko (Finland's largest retailers)
* Single platform for automating key processes
* Model design, data pipelines, workflow management, deployments
* Powered by Agile Data Engine on Snowflake

#### Petco (Pet Retail)
* Built advanced real-time analytics platform
* Scalable data pipeline for real-time ingestion and processing

### Insurance & Risk

#### Progressive Insurance
* Real-time speed data analysis
* Customer behavior analysis for usage-based pricing
* Delivers appropriate discounts based on driving patterns

### Healthcare

#### nib group (Australian Health Insurance)
* Adopted Snowflake for cloud data warehouse
* **Integration**: Seamless with existing cloud infrastructure
* **Use cases**:
  * KPIs across claims, sales, policies, customer behavior
  * Tableau dashboards for business metrics
  * Handles large data volumes efficiently

### Travel & Hospitality
* **Customers**: Hyatt, Tripadvisor, Marriott, JetBlue, Booking.com
* **Use cases**:
  * Dynamic pricing optimization
  * Operational efficiency
  * Reputation management
  * Sustainability tracking

### Common Use Case Patterns

#### Real-Time Streaming Analytics
* **IoT/Manufacturing**: Temperature, vibration, pressure sensors
* **Retail**: Transaction processing, click-stream analysis
* **Financial**: Fraud detection, transaction monitoring
* **Technology**: Snowpipe Streaming for continuous low-latency ingestion
* Sources: Apache Kafka, CDC streams, IoT sensors, application events

#### Machine Learning & AI
* Model training and deployment within platform
* Integration with TensorFlow, PyTorch
* Large dataset loading, transformation, management
* Credit card fraud detection models
* Customer behavior prediction

#### Data Sharing & Marketplace
* **Snowflake Marketplace**: 100+ data providers in 13 categories
* **Partners**: FactSet, Fiserv, Stripe (transaction/risk data)
* **Use cases**:
  * External data enrichment (COVID-19 data, weather, demographics)
  * Supply chain visibility (vendor → logistics → customer)
  * Location intelligence (CARTO)
  * Data observability (Monte Carlo)

#### Legacy Migration
* Companies migrating from Teradata, Oracle, on-prem systems
* Examples: Penske, Siemens, PayPal, NAVEX, Core Digital Media
* Reduced cost, improved performance, eliminated physical tuning

#### Compliance & Governance
* FRTB compliance (finance)
* KYC/AML (banking)
* Data lineage tracking
* Role-based access control
* End-to-end encryption for regulated data

## Key Insights
* Separation of storage and compute critical for cloud
* Multi-cluster, shared-data architecture enables:
  * True elasticity (scale compute independently of storage)
  * Performance isolation (separate VWs for different workloads)
  * Shared data without physical copying
* Elasticity changes user behavior:
  * Can use more nodes for same cost (faster results)
  * Example: 4 nodes × 15 hours ≈ 32 nodes × 2 hours
* Schema-less semi-structured data with relational performance
  * Automatic type inference
  * Columnar storage for extracted paths
  * ~10% overhead vs pure relational
* Online upgrade critical for SaaS model
  * Weekly releases
  * No downtime
  * Can quickly downgrade if needed
* Pure service principle: no tuning, no physical design, no grooming
  * Only one parameter: performance level (VW size)
