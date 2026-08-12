# Velox: Meta's Unified Execution Engine

## Background: Modern Data Workload Types

### ETL (Extract, Transform, Load)
* **Definition**: Process of moving and transforming data from source systems to data warehouse
* **Characteristics**:
  * Batch processing (run periodically, e.g., nightly)
  * Large data volumes (GBs to TBs per run)
  * Complex transformations
  * Usually scheduled (cron jobs, Airflow)

**Real-world Example 1: E-commerce Daily Sales Report**
```
1. EXTRACT (6:00 AM daily):
   - Pull yesterday's orders from MySQL database
   - Pull product info from PostgreSQL
   - Pull customer data from MongoDB

2. TRANSFORM:
   - Join orders with products and customers
   - Calculate metrics: revenue per category, top customers
   - Clean data: remove test orders, fix null values
   - Aggregate: daily totals, regional breakdowns

3. LOAD:
   - Write results to data warehouse (e.g., Snowflake, Redshift)
   - Update summary tables for dashboards

Result: Business analysts query warehouse for reports
```

**Real-world Example 2: Social Media Analytics (Meta's use case)**
```
1. EXTRACT:
   - User posts from production databases
   - User interactions (likes, comments, shares)
   - Ad impressions and clicks

2. TRANSFORM:
   - Denormalize: Join users + posts + interactions
   - Enrich: Add geographic data, device info
   - Aggregate: Engagement metrics per post/user
   - Filter: Remove spam, deleted content

3. LOAD:
   - Store in data warehouse (Presto/Hive tables)
   - Make available for data scientists, ML training

Volume: Billions of rows per day
Runtime: Hours (that's why efficiency matters!)
```

**Real-world Example 3: Log Processing**
```
EXTRACT:
  - Server logs from 10,000 web servers
  - Application logs from microservices
  - Database query logs

TRANSFORM:
  - Parse log format (regex, JSON parsing)
  - Extract metrics: response times, error rates
  - Sessionize: Group by user sessions
  - Aggregate by time window (5-min buckets)

LOAD:
  - Write to monitoring dashboard (Grafana)
  - Store in long-term storage (S3 + Parquet)

Frequency: Every hour or day
Data volume: TBs of raw logs → GBs of metrics
```

### Bulk Data Movement
* **Definition**: Moving large amounts of data between systems
* **Characteristics**:
  * Focus on throughput, not latency
  * Minimal or no transformation
  * Often involves format conversion
  * Network and I/O intensive

**Real-world Example 1: Database Migration**
```
Scenario: Migrate from MySQL to PostgreSQL

Process:
  1. Full table export from MySQL
     - mysqldump or SELECT INTO file
     - 500GB database → CSV files

  2. Optional transformation:
     - Convert MySQL-specific types to PostgreSQL
     - Fix character encoding (latin1 → utf8)

  3. Bulk import to PostgreSQL
     - COPY command (much faster than INSERT)
     - Load 500GB in hours instead of days

Challenge: Minimize downtime, ensure data consistency
```

**Real-world Example 2: Data Lake Ingestion**
```
Scenario: Move production data to data lake daily

Source: Operational databases (PostgreSQL, MongoDB)
Target: S3 data lake in Parquet format

Process:
  1. Extract all changed rows (using change data capture)
  2. Convert to Parquet format
     - Row format (DB) → Columnar format (Parquet)
     - Compress with Snappy/ZSTD
  3. Upload to S3
  4. Update metadata catalog (Hive metastore)

Volume: 10TB/day across all tables
Benefit: Analysts can query with Spark/Presto without hitting prod DB
```

**Real-world Example 3: Cross-Region Replication**
```
Scenario: Replicate data from US datacenter to EU datacenter

Process:
  - Snapshot tables from US database
  - Transfer over network (potentially across continents)
  - Load into EU database replica
  - Enable incremental sync for ongoing changes

Challenges:
  - Network bandwidth (100 Gbps links)
  - Data consistency during transfer
  - Resume capability if transfer interrupted

Use case: GDPR compliance (EU data must stay in EU)
```

### Realtime Stream Processing
* **Definition**: Process data continuously as it arrives
* **Characteristics**:
  * Low latency (milliseconds to seconds)
  * Infinite data streams
  * Incremental computation
  * Stateful processing (windows, aggregations)

**Real-world Example 1: Fraud Detection**
```
Scenario: Credit card fraud detection

Data Stream:
  → Credit card transaction (every few seconds)
    {user_id, amount, merchant, location, timestamp}

Processing Pipeline:
  1. Filter: transactions > $1000

  2. Enrich: Join with user profile (location, history)

  3. Detect anomalies:
     - User in California 1 hour ago, now in New York?
     - Unusual merchant category for this user?
     - Transaction amount >> user's average?

  4. Aggregate (5-minute window):
     - Count transactions per user
     - Sum amount per user
     - Alert if > 10 transactions or > $10,000 in 5 min

  5. Alert: Send to fraud investigation system

Latency requirement: < 100ms
Why streaming: Can't wait for batch ETL (fraud happens now!)
```

**Real-world Example 2: Real-time Analytics Dashboard**
```
Scenario: Website traffic monitoring (like Google Analytics)

Data Stream:
  → Page view events (millions per second)
    {user_id, page_url, timestamp, referrer, device}

Processing:
  1. Parse and clean: Extract domain, path, query params

  2. Sessionize: Group events by user session
     - 30-minute inactivity timeout

  3. Aggregate (tumbling 1-minute windows):
     - Page views per page
     - Unique visitors per page
     - Bounce rate
     - Average session duration

  4. Write to dashboard: Update live charts

Result: Business sees metrics update every minute
Why streaming: Batch processing would show yesterday's data
```

**Real-world Example 3: IoT Sensor Monitoring**
```
Scenario: Smart building temperature control

Data Stream:
  → Temperature sensor readings (every 10 seconds)
    {room_id, temperature, humidity, timestamp}

Processing:
  1. Filter outliers: Ignore readings < 0°F or > 120°F

  2. Sliding window aggregation (10-minute window):
     - Average temperature per room
     - Detect rapid changes (> 5°F in 10 min)

  3. Pattern detection:
     - Too hot for >20 minutes → Increase AC
     - Too cold for >20 minutes → Increase heating

  4. Alert HVAC control system

Latency: < 30 seconds
Why streaming: Immediate response to temperature changes
```

**Real-world Example 4: Social Media Timeline (Meta's use case)**
```
Scenario: Facebook/Instagram feed updates

Data Stream:
  → New posts from friends (continuous)
    {user_id, post_id, content, timestamp}

Processing:
  1. Filter: Only posts from user's friends

  2. Rank: Apply ML model for relevance
     - User's past interactions
     - Post popularity (early engagement signals)
     - Content type preference

  3. Aggregate: Build feed for each user

  4. Push notification: If high-relevance post

Latency: < 1 second
Why streaming: Users expect immediate updates
Volume: Billions of posts/day, millions of users
```

### ML/AI Data Preprocessing
* **Definition**: Transform raw data into format suitable for ML training
* **Characteristics**:
  * Feature engineering (create ML features from raw data)
  * Data cleaning and normalization
  * Train/test split
  * Can be batch or realtime (for online learning)

**Real-world Example 1: Recommendation System Training Data**
```
Scenario: Netflix movie recommendations

Raw Data:
  - User viewing history (watched movies, watch time)
  - User ratings (1-5 stars)
  - Movie metadata (genre, actors, director, year)
  - User demographics (age, location)

Preprocessing Pipeline:
  1. Feature Engineering:
     a) User features:
        - Favorite genres (count by genre)
        - Average rating given
        - Viewing frequency (movies/week)
        - Preferred viewing time (weekend vs weekday)

     b) Movie features:
        - One-hot encode genres
        - Normalize release year
        - Average rating from all users
        - Popularity score

     c) Interaction features:
        - User-genre affinity score
        - Similar users' ratings
        - Time since last watched similar movie

  2. Data Cleaning:
     - Remove incomplete records
     - Handle missing ratings (impute or drop)
     - Filter out bot accounts

  3. Normalization:
     - Scale numerical features to [0, 1]
     - Standardize (mean=0, std=1) for neural nets

  4. Split:
     - 80% training, 10% validation, 10% test
     - Time-based split (older data = train, recent = test)

  5. Output Format:
     - TFRecord (TensorFlow) or Parquet
     - Feature vectors ready for ML model

Volume: Billions of viewing events → Millions of training examples
Why it matters: Bad features = Bad model (no matter how good the algorithm)
```

**Real-world Example 2: Image Classification Preprocessing**
```
Scenario: Train model to detect cats vs dogs

Raw Data:
  - 100,000 images (JPEG files)
  - Labels (cat or dog)

Preprocessing:
  1. Image Transformations:
     - Resize to 224x224 pixels (model input size)
     - Convert to RGB (handle grayscale)
     - Normalize pixel values: [0, 255] → [0, 1]

  2. Data Augmentation (create more training data):
     - Random horizontal flip
     - Random rotation (±15 degrees)
     - Random brightness/contrast adjustment
     - Random crop

     Original 100K images → 500K augmented images

  3. Encoding:
     - Labels: "cat" → 0, "dog" → 1 (one-hot encoding)

  4. Batching:
     - Group into batches of 32 images
     - Shuffle order (prevent learning order)

  5. Split:
     - 70% train, 15% validation, 15% test

Output: Tensors ready for PyTorch/TensorFlow

Challenges:
  - Memory: Can't load all images at once
  - I/O: Reading images is slow (need prefetching)
  - Compute: Augmentation is CPU-intensive
```

**Real-world Example 3: NLP Text Preprocessing**
```
Scenario: Train sentiment analysis model (positive/negative reviews)

Raw Data:
  - Product reviews (text + star rating)
    "This phone is amazing! Battery lasts all day." → 5 stars
    "Terrible product. Broke after 1 week." → 1 star

Preprocessing:
  1. Text Cleaning:
     - Lowercase: "Amazing" → "amazing"
     - Remove punctuation: "amazing!" → "amazing"
     - Remove HTML tags
     - Remove URLs, @mentions

  2. Tokenization:
     "This phone is amazing" → ["this", "phone", "is", "amazing"]

  3. Feature Engineering:
     a) Bag of Words:
        {"this": 1, "phone": 1, "is": 1, "amazing": 1}

     b) TF-IDF:
        Weight words by rarity
        "the" → low weight (common)
        "amazing" → high weight (distinctive)

     c) Word Embeddings:
        "amazing" → [0.2, -0.1, 0.5, ...] (300-dim vector)
        Use pre-trained (Word2Vec, GloVe)

  4. Padding/Truncation:
     - Max sequence length = 100 words
     - Pad short reviews: [w1, w2, PAD, PAD, ...]
     - Truncate long reviews: [w1, w2, ..., w100]

  5. Label Processing:
     - 1-2 stars → Negative (label = 0)
     - 4-5 stars → Positive (label = 1)
     - 3 stars → Neutral (discard or separate class)

  6. Split and Balance:
     - Ensure 50/50 positive/negative in training set
     - Undersample or oversample if imbalanced

Output: Token sequences + labels for LSTM/BERT model

Why complex: Text is unstructured, high-dimensional, sparse
```

**Real-world Example 4: Feature Engineering for Ad Click Prediction (Meta)**
```
Scenario: Predict if user will click on an ad

Raw Data:
  - User profile (age, gender, location, interests)
  - User history (past clicks, liked pages)
  - Ad content (text, image, target audience)
  - Context (time of day, device type, current page)

Feature Engineering:
  1. User Features:
     - Age group: 18-24, 25-34, ... (categorical)
     - Gender: M/F (binary)
     - Location: Country, City (categorical, millions of values!)
     - Interests: One-hot encoding (sparse, thousands of categories)
     - Activity level: Posts/day, logins/week

  2. Ad Features:
     - Ad category (e-commerce, gaming, etc.)
     - Target keywords (extracted from ad text)
     - Image embeddings (from CNN)
     - Advertiser quality score

  3. Interaction Features (most important!):
     - User-Ad category match score
     - User's past CTR for similar ads
     - Similar users' behavior on this ad

  4. Temporal Features:
     - Hour of day (0-23)
     - Day of week (0-6)
     - Is weekend? (binary)
     - Time since last ad click

  5. Embeddings:
     - User embedding (learn from behavior)
     - Ad embedding (learn from performance)
     - Dot product → similarity score

  6. Transformations:
     - Log transform: count features (log(1 + count))
     - Binning: Continuous → categorical
     - Normalization: Z-score for neural nets

Challenges:
  - High cardinality: Millions of users/ads
  - Sparse features: Most values are 0
  - Real-time: Must compute features in < 50ms for serving
  - Drift: User behavior changes over time

Volume: Billions of examples, thousands of features
Compute: This preprocessing consumes ~50% of ML resources!

This is where Velox's TorchArrow helps:
  - Fast vectorized transformations
  - Consistent functions (same as in Spark/Presto)
  - Efficient handling of complex types (arrays, maps)
```

### Comparison Table

```
Workload Type    | Latency      | Volume       | Frequency    | Example
-----------------|--------------|--------------|--------------|------------------
ETL              | Hours        | TB           | Daily/Hourly | Sales reports
Bulk Movement    | Hours        | TB-PB        | One-time     | DB migration
Stream           | Milliseconds | Infinite     | Continuous   | Fraud detection
ML Preprocessing | Minutes      | GB-TB        | Per training | Feature engineering
```

### Why Multiple Engines Existed Before Velox

**Different workloads had different engines**:
```
ETL:                  Spark, Hive (batch processing)
Stream Processing:    Flink, Storm, XStream (low latency)
Bulk Movement:        Custom scripts, Sqoop (throughput)
ML Preprocessing:     Pandas, custom Python (ML-friendly)
Analytics:            Presto, Impala (interactive queries)
```

**Each engine optimized differently**:
- ETL: Fault tolerance (long-running jobs must survive failures)
- Streaming: Low latency (process events immediately)
- Bulk: High throughput (saturate network/disk)
- ML: Integration with Python/PyTorch ecosystem

**Velox's goal**: Unified execution engine for ALL of these!

### How Meta's Products Map to Workload Types

#### ETL and Batch Analytics → **Spark (Spruce)**

**Workload**: Large-scale batch processing and ETL
```
Example: Daily aggregation of user engagement metrics

Raw data (TB scale):
  - User posts from last 24 hours (from production DB)
  - User interactions (likes, comments, shares)
  - Ad impressions and clicks

Spark ETL Pipeline:
  1. EXTRACT:
     - Read from Hive tables (yesterday's partition)
     - Load user metadata from database snapshots

  2. TRANSFORM:
     - Join posts + interactions + ad data
     - Calculate engagement rate per post
     - Compute user activity scores
     - Aggregate by region, age group, content type

  3. LOAD:
     - Write summary tables (Parquet format)
     - Update data warehouse for reporting

Runtime: 2-4 hours
Data volume: 100TB input → 10TB output
Frequency: Daily at 2 AM
```

**Why Spark needs Velox**:
- Long-running queries need efficiency (hours of CPU time)
- Better fault tolerance for multi-hour jobs
- Same function semantics as interactive analytics (Presto)

#### Interactive Analytics → **Presto (Prestissimo)**

**Workload**: Low-latency SQL queries for exploration and dashboards
```
Example: Ad-hoc analysis by data scientist

Query: "Show me top 10 advertisers by revenue in last 7 days"

SELECT advertiser_id,
       SUM(revenue) as total_revenue,
       COUNT(DISTINCT user_id) as unique_users
FROM ad_impressions
WHERE date >= current_date - interval '7' day
  AND click = true
GROUP BY advertiser_id
ORDER BY total_revenue DESC
LIMIT 10

Latency requirement: < 10 seconds
Data scanned: ~500GB (7 days of ad impressions)
Use case: Interactive exploration, dashboards, reporting
```

**Why Presto needs Velox**:
- User waiting for results (need low latency)
- Thousands of concurrent queries
- 6-10x speedup = better user experience
- 3x fewer servers = cost savings

#### Stream Processing → **XStream**

**Workload**: Continuous processing of event streams
```
Example: Real-time content moderation

Data Stream (from Scribe):
  → User posts (continuous, millions/sec)
    {user_id, post_id, content, timestamp, location}

XStream Processing:
  1. Filter: Posts with text content

  2. Enrich: Join with user reputation score
     - Read from key-value store
     - Add user's violation history

  3. Apply ML model: Toxicity detection
     - Score: 0.0 (safe) to 1.0 (toxic)

  4. Aggregation (5-minute tumbling window):
     - Count toxic posts per user
     - If count > threshold → Flag for review

  5. Write results:
     - Back to Scribe (for moderation queue)
     - To dashboard (real-time metrics)

Latency: < 1 second (post to moderation decision)
Throughput: Millions of posts/second
Window: 5-minute tumbling windows
```

**Why XStream needs Velox**:
- Low latency critical (users expect immediate moderation)
- Batched execution (up to 500KB, 20 sec) benefits from vectorization
- Reuses Presto function package (consistency)
- Temporal window aggregations (tumbling, hopping, session)

**Connection to Scribe (Messaging Bus)**:
```
Data Flow:
  Web Tier → Scribe (ingest)
       ↓
  XStream reads from Scribe
       ↓
  XStream processes (using Velox)
       ↓
  XStream writes back to Scribe
       ↓
  Downstream consumers (dashboards, storage)
```

**Why Scribe needs Velox**:
- Traditionally row-by-row reads
- Now: Columnar serialization (more efficient)
- Pushdown operations (projection, filtering) to storage
- Reduces cross-datacenter traffic

#### Bulk Data Movement / Data Ingestion → **FBETL**

**Workload Type 1: Data Warehouse Ingestion**
```
Example: Scribe → Data Warehouse pipeline

Source: Scribe pipes (message bus)
  - User activity logs (100M events/hour)
  - Application events (50M events/hour)
  - Ad events (200M events/hour)

FBETL Pipeline:
  1. Read from Scribe:
     - Batch reads (not row-by-row)
     - Using Velox columnar serialization

  2. Optional transformations:
     - Parse JSON fields
     - Apply UDFs (same as Presto functions!)
     - Filter out test data
     - Denormalize nested structures

  3. Write to warehouse:
     - ORC/DWRF format (columnar)
     - Partitioned by date/hour
     - Compressed (Snappy/ZSTD)

Throughput: 350M events/hour → 5TB/day
Frequency: Continuous (micro-batches every 5 min)
Format: Row (Scribe) → Columnar (ORC) conversion
```

**Why doing transformations in FBETL (not separate stream app)**:
- No need to write to intermediate Scribe pipe
- Saves one write + one read cycle
- Lower latency, less storage

**Workload Type 2: Database Ingestion**
```
Example: MySQL → Data Warehouse snapshots

Source: MySQL operational database
  - Read database redo logs (change data capture)
  - Previous snapshot from warehouse

FBETL Snapshot Process:
  1. Read previous snapshot (Parquet/ORC)
  2. Read incremental changes from MySQL logs
  3. Merge changes (like merge-join operator)
  4. Write new snapshot

Schedule: Daily (full snapshot of production DB)
Volume: 10TB database → 10TB snapshot
Use case: Analytics on operational data without hitting prod DB
```

**Why FBETL needs Velox**:
- Reuses ORC encoder from Spark/Presto (consistency)
- Same transformation functions (UDFs)
- Snapshotting uses merge-join operator
- Efficient columnar processing

#### ML Data Preprocessing → **TorchArrow (PyTorch)**

**Workload**: Feature engineering for ML training
```
Example: Training a recommendation model

Raw Data (from data warehouse):
  - User viewing history (10B events)
  - User ratings (1B ratings)
  - Content metadata (100M items)
  - User demographics (1B users)

TorchArrow Preprocessing:
  1. Feature Engineering:
     # User features
     user_features = df.group_by('user_id').agg(
       favorite_genre=most_common('genre'),
       avg_rating=mean('rating'),
       watch_frequency=count() / time_span_days('timestamp')
     )

     # Content features
     content_features = df.group_by('content_id').agg(
       avg_rating=mean('rating'),
       popularity=count(),
       genre_vector=one_hot_encode('genre')
     )

     # Interaction features
     interactions = df.join(user_features, on='user_id')
                      .join(content_features, on='content_id')
                      .select(
                        'user_id',
                        'content_id',
                        user_genre_match(user.favorite_genre, content.genre),
                        days_since_last_watch('timestamp')
                      )

  2. Transformations (using Velox functions):
     - Array operations: array_agg(), flatten()
     - Map operations: map_keys(), map_values()
     - String processing: regexp_extract(), split()
     - Math: log(), sqrt(), normalize()

  3. Data Cleaning:
     - Remove nulls: filter(is_not_null())
     - Remove outliers: filter(rating.between(1, 5))
     - Deduplicate: distinct()

  4. Output:
     - Convert to PyTorch tensors
     - Save as TFRecord or Parquet
     - Ready for model training

Volume: 10B events → 500M training examples
Runtime: 30 minutes (previously 2 hours with Pandas!)
```

**Why ML preprocessing needed Velox**:
- **Problem before**: 14 different preprocessing libraries at Meta
  - Inconsistent functions (different substr() implementations!)
  - Poor performance (Pandas doesn't scale)
  - Incompatible with Data Analytics tools

- **Solution with Velox**:
  - Same function package as Presto/Spark
  - Vectorized execution (10-100x faster than Pandas)
  - Consistent semantics (no surprises)
  - "DI for AI" - Data Infrastructure for Artificial Intelligence

#### Feature Engineering → **F3**

**Workload**: Define features once, use everywhere
```
Example: User engagement score feature

F3 DSL Definition:
  feature UserEngagementScore:
    sources:
      - user_posts (from data warehouse)
      - user_interactions (from stream)

    transformations:
      posts_per_day = count(posts) / days_active
      avg_likes_per_post = sum(likes) / count(posts)
      engagement_score = (posts_per_day * 0.3 +
                         avg_likes_per_post * 0.7)

    output: float

Three Execution Paths:
  1. Offline (batch training data):
     - F3 → Spark (uses Velox)
     - Generate historical features
     - 1B users × 1000 features = 1TB dataset

  2. Realtime (streaming features):
     - F3 → XStream (uses Velox)
     - Update features as events arrive
     - Low latency (<1 sec)

  3. Online (serving/inference):
     - F3 → Online serving system
     - Compute features during prediction
     - Very low latency (<10ms)
     - Currently exploring codegen (not vectorization)
```

**Why F3 needs Velox**:
- **Offline + Realtime**: Already using Velox (via Spark + XStream)
- **Online serving**: Challenge!
  - High QPS (queries per second)
  - Low latency (<10ms)
  - Small batches (often single row)
  - **Vectorization overhead too high**
  - Solution: Code generation (experimental)

**Consistency benefit**:
```
Same feature definition used in:
  Training (Spark) → Uses Velox vectorized
  Streaming (XStream) → Uses Velox vectorized
  Serving (online) → Uses Velox codegen (future)

Result: No training/serving skew!
  - Feature computed same way everywhere
  - Model sees same features in training and production
```

### Summary: Velox Integration Across Meta's Stack

```
Product      | Workload Type        | Velox Components Used           | Key Benefit
-------------|----------------------|---------------------------------|------------------
Spark        | ETL/Batch            | Full stack                      | 2x speedup
Presto       | Interactive SQL      | Full stack                      | 6-10x speedup
XStream      | Stream processing    | Operators, functions, vectors   | Low latency + consistency
Scribe       | Messaging            | Serializers, vectors            | Efficient reads, pushdown
FBETL        | Data ingestion       | I/O, serializers, functions     | Consistency, no intermediate storage
TorchArrow   | ML preprocessing     | All except operators            | 10-100x vs Pandas
F3           | Feature engineering  | Functions, expression eval      | Train/serve consistency
```

**The Big Picture**:
```
User Activity
     ↓
Scribe (uses Velox for efficient reads)
     ↓
  ┌──┴───────────────────────────────┐
  ↓                                  ↓
XStream (stream)              FBETL (batch ingest)
Uses Velox                    Uses Velox
  ↓                                  ↓
Scribe (results)              Data Warehouse (ORC)
  ↓                                  ↓
Dashboards                     ┌─────┴──────┐
                               ↓            ↓
                          Presto (SQL)  Spark (ETL)
                          Uses Velox    Uses Velox
                               ↓            ↓
                          Analytics    Training Data
                                           ↓
                                    TorchArrow (ML prep)
                                    Uses Velox
                                           ↓
                                    F3 (features)
                                    Uses Velox
                                           ↓
                                    ML Training
                                           ↓
                                    Model Serving

All these systems share Velox execution engine!
  → Same functions
  → Consistent behavior
  → Develop optimizations once
```

## Motivation: The Siloed Data Ecosystem Problem

### The Proliferation Problem
* Modern data workloads are diverse:
  * Transaction processing (OLTP)
  * Batch and interactive analytics (OLAP)
  * ETL and bulk data movement
  * Realtime stream processing
  * ML/AI data preprocessing and feature engineering
* Led to dozens of specialized engines:
  * Each targeted to specific workload type
  * Built with different frameworks and libraries
  * Written in different languages
  * Maintained by different teams
  * **Share little to nothing with each other**

### Problems with Fragmentation

#### 1. Maintenance and Evolution Cost
* Evolving engines for new hardware (GPUs, NVRAM, accelerators) requires per-engine work
* Supporting new features (Tensor types for ML) across all engines is impractical
* Engines end up with disparate sets of optimizations

#### 2. Inconsistent User Experience
* Same functions behave differently across engines
* Example at Meta: **12 different implementations of substr()**
  * Different parameter semantics (0-based vs 1-based indices)
  * Different null handling
  * Different exception behavior
* Users must interact with multiple engines to complete tasks
* Available data types, functions, aggregates vary across systems

#### 3. Engineering Duplication
* Same functionality implemented multiple times
* Example: All engines need:
  * Type system for scalar and complex types
  * Columnar memory representation
  * Expression evaluation
  * Operators (joins, aggregation, sort)
  * Serialization formats
  * Resource management

### Key Observation
* **Engines differ mainly in**:
  * Language frontend (SQL, dataframes, DSLs)
  * Query optimizer
  * Task distribution (runtime)
  * IO layer
* **Execution engines are all rather similar**
  * This is where Velox fits in!

## What is Velox?

### Definition
* Open source C++ database acceleration library
* Provides reusable, extensible, high-performance data processing components
* Can be used to build, enhance, or replace execution engines

### Key Characteristics
* **Vectorized execution**: Process data in batches (columnar)
* **Adaptive**: Runtime optimizations based on data characteristics
* **Complex type support**: Designed for nested/complex data types from ground up
* **Dialect-agnostic**: Works with any SQL dialect or query language
* **Modular**: Pick and choose components needed
* **Extensible**: Many hooks for customization

### What Velox Does NOT Provide
* ❌ SQL parser
* ❌ Dataframe layer or other DSLs
* ❌ Global query optimizer
* ❌ Distributed runtime / task scheduling

### Input and Output
* **Input**: Fully optimized query plan (as operator tree)
* **Output**: Executes computation using local node resources
* Velox sits on the **data-plane**, engines provide **control-plane**

### Value Proposition

#### 1. Efficiency
* Democratizes optimizations previously in individual engines:
  * SIMD leveraging
  * Lazy evaluation
  * Adaptive predicate reordering
  * Common subexpression elimination
  * Execution over encoded data
  * Code generation

#### 2. Consistency
* All engines using Velox expose same:
  * Data types
  * Scalar/aggregate function packages
  * Behavior and semantics

#### 3. Engineering Efficiency
* Features and optimizations developed once
* Maintained once
* Reduces duplication

## Core Optimizations Explained

### 1. SIMD Leveraging (Single Instruction, Multiple Data)

**What is SIMD?**:
* CPU instruction that processes multiple data elements in parallel
* Modern CPUs (x86-64 with AVX2/AVX-512) can operate on:
  * 4 × 64-bit integers per instruction (AVX2)
  * 8 × 32-bit integers per instruction (AVX2)
  * 16 × 16-bit integers per instruction (AVX2)
  * 8 × 64-bit integers per instruction (AVX-512)

**How it Works**:
```
Scalar (traditional):
  for (int i = 0; i < 1000; i++) {
    result[i] = a[i] + b[i];  // 1 addition per clock cycle
  }

  Time: 1000 clock cycles

SIMD (AVX2):
  for (int i = 0; i < 1000; i += 4) {
    __m256i va = _mm256_load_si256(&a[i]);     // Load 4 × 64-bit
    __m256i vb = _mm256_load_si256(&b[i]);     // Load 4 × 64-bit
    __m256i vr = _mm256_add_epi64(va, vb);     // 4 additions in 1 cycle!
    _mm256_store_si256(&result[i], vr);        // Store 4 × 64-bit
  }

  Time: 250 clock cycles (4x speedup!)
```

**Example in Velox (Filter Execution)**:
```
Query: SELECT * FROM table WHERE age > 30

Input: Vector with 1024 ages
       [25, 35, 42, 28, 50, 31, ...]

Without SIMD (scalar):
  for (int i = 0; i < 1024; i++) {
    if (ages[i] > 30) {
      output_indices[count++] = i;
    }
  }
  Time: ~1024 comparisons

With SIMD (AVX2 - 8 × 32-bit ints):
  __m256i threshold = _mm256_set1_epi32(30);  // Broadcast 30 to all lanes

  for (int i = 0; i < 1024; i += 8) {
    __m256i ages_vec = _mm256_load_si256(&ages[i]);
    __m256i mask = _mm256_cmpgt_epi32(ages_vec, threshold);
    // mask = [0xFF..FF, 0, 0xFF..FF, 0, ...] for [35, 25, 42, 28, ...]

    int bitmask = _mm256_movemask_epi8(mask);
    // Extract passing indices using bit manipulation
    // Write to output_indices
  }

  Time: ~128 iterations (8x fewer)
  Actual speedup: 5-6x (overhead from extracting indices)
```

**Real Performance Impact**:
```
Operation               Scalar      SIMD (AVX2)   Speedup
Integer comparison      1.0 ns/val  0.2 ns/val    5x
Null bitmap check       0.5 ns/val  0.1 ns/val    5x
Integer addition        0.8 ns/val  0.15 ns/val   5.3x
Bitwise AND (filters)   0.3 ns/val  0.05 ns/val   6x
```

**Velox's Approach**:
* Compiler auto-vectorization: Let compiler generate SIMD code
* Hand-written SIMD: Critical paths (filters, aggregations)
* Simple Function API benefits: Compilers can auto-vectorize simple loops

### 2. Lazy Evaluation

**What is Lazy Evaluation?**:
* Delay computing values until actually needed
* May avoid computation entirely if values unused

**Example 1: Conditional Expressions**:
```sql
SELECT
  CASE
    WHEN status = 'active' THEN expensive_function(data)
    ELSE 0
  END
FROM table

Input: 1M rows, 10% status = 'active'

Eager Evaluation (bad):
  1. Compute expensive_function(data) for ALL 1M rows
  2. Evaluate condition
  3. Select appropriate value

  Time: 1M × expensive_function_cost = 100 seconds

Lazy Evaluation (good):
  1. Evaluate condition (status = 'active')
     → 100K rows pass, 900K rows fail
  2. Compute expensive_function() ONLY for 100K passing rows
  3. Set 0 for 900K failing rows

  Time: 100K × expensive_function_cost = 10 seconds

  Speedup: 10x!
```

**How Velox Implements It**:
```
Lazy Vector: Wrapper around unevaluated expression

Structure:
  LazyVector {
    expression_tree: Expression to evaluate
    row_set: Which rows to evaluate (initially all)
    is_loaded: false
    value_vector: null (until loaded)
  }

When accessed:
  if (!is_loaded) {
    value_vector = evaluate(expression_tree, row_set);
    is_loaded = true;
  }
  return value_vector;
```

**Example 2: Unused Columns in Joins**:
```sql
SELECT t1.id, t1.name
FROM table1 t1
JOIN table2 t2 ON t1.id = t2.id

Table1 schema: id, name, data1, data2, data3, data4
                               ↑ These columns unused in output!

Without Lazy Evaluation:
  1. Read ALL columns from table1: id, name, data1, data2, data3, data4
  2. Hash join on id
  3. Project id, name

  I/O: 6 columns × 1GB each = 6GB read from disk/S3

With Lazy Evaluation:
  1. Create Lazy Vectors for data1, data2, data3, data4
  2. Read only id (for join key)
  3. Hash join on id
  4. Project id, name → Read name column NOW
  5. data1-4 NEVER materialized!

  I/O: 2 columns × 1GB each = 2GB read

  Savings: 4GB I/O avoided!
```

**Example 3: Remote Storage (S3)**:
```
Query: SELECT * FROM s3_table WHERE region = 'US'

Table on S3: 100 columns, 1TB total, region filter selectivity = 1%

Without Lazy:
  1. Read all 100 columns from S3
     S3 read: 1TB × $0.09/GB = $90
     Time: 1TB / 100MB/s = 10,000 seconds
  2. Filter by region
  3. Return 1% of rows

With Lazy:
  1. Read only region column
  2. Filter → 1% of rows pass
  3. Read other 99 columns ONLY for 1% of rows
     S3 read: 0.01TB + 0.99TB × 0.01 = 0.01TB + 0.01TB = 0.02TB
     Cost: $1.80 (50x cheaper!)
     Time: 200 seconds (50x faster!)
```

### 3. Adaptive Predicate Reordering

**Problem**:
```sql
SELECT * FROM table
WHERE expensive_function(x) AND cheap_check(y)

Question: Which predicate to evaluate first?
  - expensive_function() takes 1 microsecond
  - cheap_check() takes 10 nanoseconds
```

**Solution: Adaptive Reordering**:
```
Metric for each predicate:
  cost = time_spent / (rows_in - rows_out + 1)

  Lower cost = better (fast + selective)

Example:

Predicate A: cheap_check(y)
  - Time: 10 ns/row
  - Selectivity: 50% (drops half the rows)
  - Cost: 10 / (100 - 50 + 1) = 10 / 51 = 0.196

Predicate B: expensive_function(x)
  - Time: 1000 ns/row
  - Selectivity: 90% (drops 90% of rows)
  - Cost: 1000 / (100 - 90 + 1) = 1000 / 11 = 90.9

Decision: Evaluate A first (lower cost)
```

**Execution Strategy**:
```
Initial order (from query):
  WHERE expensive_function(x) AND cheap_check(y)

After seeing first batch (1024 rows):

  Stats:
    expensive_function(x): 1024ms, 100 rows pass → cost = 1024/925 = 1.1
    cheap_check(y): 10ms, 500 rows pass → cost = 10/525 = 0.019

  Reorder: cheap_check(y) AND expensive_function(x)

Execution on next batches:
  1. Evaluate cheap_check(y) on all 1024 rows → 500 pass
  2. Evaluate expensive_function(x) ONLY on 500 rows

  Time saved: 1024 × 1ms - 500 × 1ms = 524ms per batch!
```

**Real-World Example**:
```sql
SELECT * FROM logs
WHERE parse_json(data) LIKE '%error%'    -- Expensive: 10 µs
  AND timestamp > '2025-01-01'           -- Cheap: 5 ns
  AND user_id IN (SELECT ...)            -- Medium: 100 ns

Initial execution (batch 1):
  Order: parse_json, timestamp, user_id (query order)
  Time: 10ms

After batch 1, reorder based on cost:
  Order: timestamp, user_id, parse_json

  timestamp: Filters 95% of rows (very selective!)
  user_id: Filters 80% of remaining
  parse_json: Only runs on 1% of original rows

  Time: 0.5ms per batch (20x faster!)
```

**Flattening Nested AND/OR**:
```sql
WHERE (a AND b) AND (c AND (d AND e))

Before flattening:
  Tree depth = 4
  Must evaluate in nested order

After flattening:
  WHERE a AND b AND c AND d AND e

  Now can reorder: e, b, a, d, c (based on cost)
```

### 4. Common Subexpression Elimination (CSE)

**What is CSE?**:
* Identify repeated computations in expression tree
* Compute once, reuse result

**Example 1: Duplicate Function Calls**:
```sql
SELECT
  upper(name) AS name_upper,
  length(upper(name)) AS name_length,
  upper(name) LIKE 'JOHN%' AS is_john
FROM users

Expression tree (before CSE):
  Project [
    upper(name),              // Call 1
    length(upper(name)),      // Call 2 (duplicates upper!)
    upper(name) LIKE 'JOHN%'  // Call 3 (duplicates upper!)
  ]

After CSE:
  temp1 = upper(name)         // Compute ONCE

  Project [
    temp1,                    // Reuse
    length(temp1),            // Reuse
    temp1 LIKE 'JOHN%'        // Reuse
  ]

Performance:
  Without CSE: 3 × upper() calls = 300 ns
  With CSE: 1 × upper() call = 100 ns
  Speedup: 3x
```

**Example 2: Complex Filter**:
```sql
SELECT * FROM events
WHERE (log(price) > 2.5 AND category = 'A')
   OR (log(price) < 1.0 AND category = 'B')

Before CSE:
  OR [
    AND [log(price) > 2.5, category = 'A'],     // Computes log(price)
    AND [log(price) < 1.0, category = 'B']      // Computes log(price) again!
  ]

After CSE:
  temp_log_price = log(price)    // Compute once

  OR [
    AND [temp_log_price > 2.5, category = 'A'],
    AND [temp_log_price < 1.0, category = 'B']
  ]

Performance (1M rows):
  Without CSE: 2M log() calls = 200ms
  With CSE: 1M log() calls = 100ms
```

**Example 3: Nested Expressions**:
```sql
SELECT
  CASE
    WHEN substr(email, 1, 5) = 'admin' THEN 'Admin'
    WHEN substr(email, 1, 5) = 'user_' THEN 'User'
    ELSE 'Other'
  END
FROM users

Before CSE:
  CASE [
    substr(email, 1, 5) = 'admin',   // Call 1
    substr(email, 1, 5) = 'user_',   // Call 2 (duplicate!)
  ]

After CSE:
  temp_prefix = substr(email, 1, 5)   // Compute once

  CASE [
    temp_prefix = 'admin',
    temp_prefix = 'user_',
  ]

Speedup: 2x (especially significant if substr is expensive)
```

### 5. Execution Over Encoded Data

**What is it?**:
* Process data in compressed/encoded form
* Avoid decompression when possible

**Dictionary Encoding**:
```
Raw data (1000 rows):
  ["red", "blue", "red", "green", "blue", "red", ...]

  Size: 1000 × 8 bytes (avg) = 8KB

Dictionary encoded:
  Dictionary: ["red", "blue", "green"]  (3 values, 24 bytes)
  Indices: [0, 1, 0, 2, 1, 0, ...]      (1000 × 4 bytes = 4KB)

  Total size: 4KB + 24 bytes (50% reduction!)
```

**Optimization: Operate on Dictionary, Not Data**:
```sql
SELECT upper(color) FROM products

Input (dictionary encoded):
  Indices: [0, 1, 0, 2, 1, 0, ...] (1000 values)
  Dict: ["red", "blue", "green"]   (3 values)

Naive approach:
  1. Decode all 1000 values
  2. Apply upper() 1000 times
  3. Re-encode result

  Calls: 1000 × upper()

Optimized (execution over encoded data):
  1. Apply upper() to dictionary: ["RED", "BLUE", "GREEN"]
  2. Keep same indices: [0, 1, 0, 2, 1, 0, ...]

  Calls: 3 × upper() (333x fewer!)

  Speedup: 100-300x for low-cardinality columns
```

**Memoization Across Batches**:
```
Batch 1:
  Indices: [0, 1, 0, 2, 1, ...]
  Dict: ["red", "blue", "green"] (base_vector_id = 12345)

  upper(dict) = ["RED", "BLUE", "GREEN"]
  Cache: {12345 → ["RED", "BLUE", "GREEN"]}

Batch 2:
  Indices: [2, 0, 0, 1, 2, ...]  (Different indices!)
  Dict: ["red", "blue", "green"] (same base_vector_id = 12345)

  Check cache: Found 12345!
  Result: Reuse cached ["RED", "BLUE", "GREEN"]

  Computation: 0 function calls (infinite speedup!)
```

**Real-World Example: Regular Expression**:
```sql
SELECT * FROM logs
WHERE message REGEXP '^ERROR.*database'

Input: 1M rows, 100 distinct messages (high duplication)

Without optimization:
  - Decode all strings
  - Run regex 1M times
  - Time: 1M × 50µs = 50 seconds

With dictionary optimization:
  - Run regex on 100 distinct values
  - Build bitmap of matching indices
  - Apply bitmap to 1M rows
  - Time: 100 × 50µs + 1M × 1ns = 5ms + 1ms = 6ms

  Speedup: 8,333x!
```

**Constant Encoding Optimization**:
```
All values in vector are same:
  Vector: [42, 42, 42, ..., 42] (1024 rows)

  Encoded: Constant(value=42, size=1024)

Filter: value > 30

  Without optimization:
    Check 1024 values: all pass

  With optimization:
    Check constant value: 42 > 30? Yes
    Generate all-true bitmap instantly
    Time: O(1) instead of O(n)
```

### 6. Code Generation

**What is Code Generation?**:
* Convert expression tree to C++ source code
* Compile to native machine code
* Fuses operations, eliminates virtual calls

**Example Expression**:
```sql
SELECT (a + b) * c + 100 FROM table

Expression tree:
    +
   / \
  *   100
 / \
+   c
/ \
a   b
```

**Interpreted Execution (Vectorized)**:
```cpp
Vector eval(RowBatch batch) {
  Vector temp1 = add(batch.column("a"), batch.column("b"));
  Vector temp2 = multiply(temp1, batch.column("c"));
  Vector result = add(temp2, constant(100));
  return result;
}

Characteristics:
  - 3 temporary vectors allocated
  - 3 function calls
  - 3 separate loops over data
  - Poor CPU cache utilization
```

**Generated Code**:
```cpp
// Generated C++ code
void eval_generated(int64_t* a, int64_t* b, int64_t* c,
                    int64_t* result, int n) {
  for (int i = 0; i < n; i++) {
    result[i] = (a[i] + b[i]) * c[i] + 100;
  }
}

// Compiled to machine code (example x86-64 assembly):
loop:
  movq (%rdi,%rcx,8), %rax    // Load a[i]
  addq (%rsi,%rcx,8), %rax    // Add b[i]
  imulq (%rdx,%rcx,8), %rax   // Multiply by c[i]
  addq $100, %rax             // Add 100
  movq %rax, (%r8,%rcx,8)     // Store result[i]
  incq %rcx                   // i++
  cmpq %rcx, %r9              // i < n?
  jl loop

Characteristics:
  - NO temporary vectors
  - NO function calls (inlined)
  - Single loop (better cache)
  - Compiler optimizations (instruction reordering, register allocation)
```

**Performance Comparison**:
```
Benchmark: (a + b) * c + 100 on 1M rows

Vectorized interpreter:
  - 3 vector allocations: 24 MB memory
  - 3 passes over data
  - Time: 15 ms

Code generation:
  - 0 temporary allocations
  - 1 pass over data
  - Time: 5 ms

  Speedup: 3x
```

**Complex Example with Conditionals**:
```sql
SELECT
  CASE
    WHEN status = 'active' THEN price * 1.1
    WHEN status = 'inactive' THEN price * 0.5
    ELSE price
  END

Generated code:
  for (int i = 0; i < n; i++) {
    if (status[i] == ACTIVE) {
      result[i] = price[i] * 1.1;
    } else if (status[i] == INACTIVE) {
      result[i] = price[i] * 0.5;
    } else {
      result[i] = price[i];
    }
  }

Benefits:
  - Branch predictor can learn patterns
  - No vector materialization for branches
  - Tight loop → better CPU cache usage
```

**Trade-offs in Velox**:

**Pros**:
* 2-10x speedup for complex expressions
* Eliminates temporary allocations
* Better for long-running queries (ETL)

**Cons**:
* Compilation time: 10-30 seconds
* Only beneficial if query runs longer than compilation time
* Breaks adaptivity (can't change plan at runtime)

**When to Use**:
```
Code generation good for:
  - Long-running ETL queries (hours)
  - Repeated queries (compile once, use many times)
  - Feature engineering (fixed expressions)

Vectorized execution good for:
  - Interactive queries (seconds)
  - Ad-hoc exploration
  - Adaptive execution
  - Short-lived queries
```

**Current Status in Velox**:
* Experimental feature
* C++ code generation via templates
* gcc/clang compilation to .so
* Loaded dynamically at runtime
* Open question: When to switch between vectorized and codegen?

## Library Components Overview

### 1. Type System
* Generic type system for scalar and complex types
* Supports:
  * Primitives: integers, floats, strings, dates, timestamps
  * Complex: structs, maps, arrays, tensors
  * Functions (lambdas)
* Extensible for engine-specific types

### 2. Vector
* Arrow-compatible columnar memory layout
* Multiple encodings:
  * Flat, Dictionary, Constant, Sequence/RLE, Bias
* Lazy materialization pattern
* Out-of-order result population support

### 3. Expression Eval
* Fully vectorized expression evaluation engine
* Optimizations:
  * Common subexpression elimination
  * Constant folding
  * Efficient null propagation
  * Encoding-aware evaluation
  * Dictionary memoization

### 4. Functions
* APIs for building custom scalar and aggregate functions
* **Simple API**: Row-by-row, easy to write
* **Vectorized API**: Batch-by-batch, high performance
* Function packages for Presto and Spark dialects included

### 5. Operators
* Common data processing operators:
  * TableScan, Project, Filter
  * Aggregation, HashJoin, MergeJoin
  * Exchange/Merge, OrderBy, Unnest

### 6. I/O
* Generic connector interface
* Pluggable file format encoders/decoders
* Storage adapters
* Built-in support:
  * Formats: ORC, Parquet
  * Storage: S3, HDFS

**File Formats**:

**ORC (Optimized Row Columnar)**:
* Columnar storage format for analytics workloads
* Key characteristics:
  * Column-major layout (good for analytics queries that select few columns)
  * Built-in compression (Zlib, Snappy, ZSTD)
  * Stripe-based organization (groups of rows, typically 64MB)
  * Lightweight indexes and statistics per stripe (min/max, count)
  * Predicate pushdown support (skip stripes based on statistics)
* Benefits:
  * Read only columns needed (vs row formats that read entire rows)
  * High compression ratios (similar columns compress well)
  * Efficient for scans and aggregations
* Common at Meta: Data warehouse storage format
* Alternative: **Parquet** (similar columnar format, more ecosystem support)

### 7. Serializers
* Network communication serialization
* Wire protocol interface
* Supports: PrestoPage, Spark UnsafeRow

### 8. Resource Management
* Memory arenas and buffer management
* Tasks, drivers, thread pools
* Spilling support
* Caching (memory and SSD)

## Use Cases at Meta

### 1. Presto (Prestissimo)
* **Goal**: Replace Java workers with C++ for efficiency
* **What it uses**: Full Velox stack
* **Architecture**:
  ```
  Java Coordinator (unchanged)
    ↓ HTTP REST
  C++ Worker (Prestissimo)
    ↓ Uses Velox for execution
  No JVM, No GC on workers!
  ```
* **Benefits**:
  * Eliminates JVM overhead and GC issues
  * 6-10x average speedup on real workloads
  * Up to 8.4x speedup on CPU-bound queries (TPC-H Q1)
  * **3x fewer servers** for same workload (60 → 20 servers)

### 2. Spark (Spruce)
* **Goal**: Accelerate batch/ETL workloads
* **Integration**: Uses Spark script transform interface
  ```
  Spark Executor (Scala/Java)
    ↓ Spark script transform
  External C++ Process (SparkCpp)
    ↓ Uses Velox for execution
  ```
* **Customization**:
  * Custom operators for Spark compatibility
  * UnsafeRow serializer for data shuffling
  * Spark-specific scalar/aggregate functions

### 3. Stream Processing (XStream)
* **What**: Meta's stream processing platform
* **Data flow**:
  ```
  Scribe (messaging) → XStream → Scribe/Scuba/KV stores
  ```
* **Characteristics**:
  * Batched execution (up to 500KB, 20 second window)
  * Benefits from vectorized execution despite row-at-a-time abstraction
* **Integration**:
  * Most operations map directly to Velox operators
  * Exposes same function package as Presto (consistency!)
  * Custom windowing aggregations (tumbling, hopping, session)

### 4. Messaging Bus (Scribe)
* **What**: Distributed messaging for log collection/aggregation
* **Velox usage**:
  * Columnar serialization formats for reads
  * Predicate/projection pushdown to storage
  * Reduces cross-datacenter traffic
  * Same semantics as compute engines (consistency!)

### 5. Data Ingestion (FBETL)
* **Use cases**:
  * Data warehouse ingestion (Scribe → ORC/DWRF files)
  * Database ingestion (DB logs → warehouse snapshots)
* **Benefits**:
  * Reuses ORC encoder from other engines (consistency)
  * Allows transformations at ingestion time
  * Same function package as Presto/Spark
  * Eliminates need for separate stream processing app

### 6. Machine Learning (TorchArrow)
* **Problem**: 14 different data preprocessing libraries at Meta
  * Incomplete type support
  * Incompatible memory representations
  * Inconsistent function packages
  * Preprocessing consumes ~50% of ML resources
* **Solution**: TorchArrow - Python dataframe layer on Velox
  * Pandas-like API
  * Translates to Velox plans
  * Consolidates Data Analytics + ML infrastructure
  * **"DI for AI"** (Data Infrastructure for Artificial Intelligence)

### 7. Feature Engineering (F3)
* **What**: Framework for ML feature engineering
* **Integration**:
  * Offline: Spark (already using Velox)
  * Realtime: XStream (already using Velox)
  * Online serving: Exploring codegen for low-latency/high-QPS

## Vectors: Columnar Memory Layout

### What is Apache Arrow?

**Definition**:
* Open-source, language-agnostic columnar memory format
* Standard for in-memory analytics data
* Created in 2016 by Wes McKinney (Pandas creator) and Dremio team

**Problem Arrow Solves**:
```
Before Arrow (serialization overhead):

Pandas (Python)
    ↓ serialize to CSV/JSON/Pickle
Network/File
    ↓ deserialize
Spark (JVM)
    ↓ serialize to different format
Network/File
    ↓ deserialize
TensorFlow (C++)

Result: Copying and converting data repeatedly!
  - CPU waste (serialize/deserialize)
  - Memory waste (multiple copies)
  - Time waste (minutes for GB of data)
```

```
With Arrow (zero-copy):

Pandas → Arrow format (in memory)
           ↓
Spark → Reads same Arrow memory (zero-copy!)
           ↓
TensorFlow → Reads same Arrow memory (zero-copy!)

Result: Direct memory sharing across languages/engines
```

**Why Arrow is Needed**:

1. **Eliminate serialization overhead**:
   ```
   Example: Python → Spark communication

   WITHOUT Arrow:
     1. Python creates Pandas DataFrame (Python objects)
     2. Serialize to Pickle format (slow!)
     3. Send over socket
     4. JVM deserializes to Spark Row objects
     5. Convert to columnar format for processing

     Time: 30 seconds for 1GB DataFrame
     Memory: 3x overhead (Python, Pickle, JVM copies)

   WITH Arrow:
     1. Python creates Arrow Table (columnar)
     2. Send Arrow buffers (just memory pointers!)
     3. JVM reads Arrow buffers directly
     4. Already in columnar format!

     Time: < 1 second (100MB/s network)
     Memory: 1x (single copy)
   ```

2. **Standardized columnar format**:
   - All analytics systems use same in-memory layout
   - CPU cache-friendly (column-at-a-time access)
   - SIMD-friendly (vectorized operations)

3. **Interoperability**:
   ```
   Supported by 13+ languages:
     - Python (Pandas, PyArrow)
     - Java/Scala (Spark)
     - C++ (many databases)
     - R, Go, Rust, JavaScript, ...

   Supported by 50+ projects:
     - Databases: Spark, Presto, ClickHouse, DuckDB
     - Analytics: Pandas, Polars, Dask
     - Visualization: Tableau, Grafana
     - ML: TensorFlow, PyTorch (via libraries)
     - Storage: Parquet (uses Arrow-like encoding on disk)
   ```

**Arrow Format Basics**:
```
Example: Column of integers [10, null, 30, 40]

Arrow Representation:
  ┌─────────────────────────────────────┐
  │ Schema (metadata)                   │
  │   - Column name: "age"              │
  │   - Type: int32                     │
  │   - Nullable: true                  │
  └─────────────────────────────────────┘
  ┌─────────────────────────────────────┐
  │ Nullability Bitmap (1 bit per row)  │
  │   [1, 0, 1, 1]  (0 = null)          │
  │   Packed: 0b1101 = 13               │
  └─────────────────────────────────────┘
  ┌─────────────────────────────────────┐
  │ Values Buffer (contiguous array)    │
  │   [10, ??, 30, 40]  (?? = garbage)  │
  │   Memory: 4 bytes × 4 = 16 bytes    │
  └─────────────────────────────────────┘

Benefits:
  - Null bitmap separate from values (efficient SIMD)
  - Values contiguous (cache-friendly)
  - Fixed-size types = direct array indexing
```

**Real-World Example: Data Pipeline**:
```
Scenario: Load CSV, process in Spark, visualize in Pandas

Step 1: Read CSV with PyArrow
  import pyarrow.csv as csv
  table = csv.read_csv("data.csv")  # → Arrow Table

  Memory: Arrow columnar format (efficient)

Step 2: Process in Spark (via PySpark)
  df = spark.createDataFrame(table.to_pandas())

  OLD way: table.to_pandas() converts to Python objects
           → Spark serializes with Pickle (slow!)

  NEW way (Arrow enabled):
    spark.conf.set("spark.sql.execution.arrow.pyspark.enabled", "true")
    df = spark.createDataFrame(table.to_batches(), schema)
    → Spark reads Arrow batches directly (zero-copy!)

Step 3: Results back to Pandas for plotting
  result = df.toPandas()  # Uses Arrow (fast!)

  Without Arrow: 45 seconds
  With Arrow: 3 seconds (15x faster!)
```

**How Arrow Solves Cross-Process/Machine Memory Access**:

**Case 1: Same Machine, Different Processes (True Zero-Copy)**:
```
Python Process A                    Spark Process B
     ↓                                    ↓
Creates Arrow Table              Reads Arrow Table
     ↓                                    ↓
Writes to Shared Memory          Memory-maps same file
(mmap or /dev/shm)              (mmap with SHARED flag)
     ↓                                    ↓
  ┌──────────────────────────────────────┐
  │   Shared Memory Region (OS kernel)   │
  │   Arrow buffers (metadata + data)    │
  └──────────────────────────────────────┘
     ↑                                    ↑
Both processes read SAME physical memory pages!

Result: ZERO memory copies, just pointer sharing
```

**Example (same machine)**:
```python
# Process A (Python): Write to shared memory
import pyarrow as pa
import pyarrow.plasma as plasma  # Shared memory object store

# Connect to Plasma store (shared memory manager)
client = plasma.connect("/tmp/plasma")

# Create Arrow table
table = pa.table({'x': [1, 2, 3], 'y': [4, 5, 6]})

# Put in shared memory, get object ID
object_id = client.put(table)
# → Arrow buffers written to /dev/shm (Linux) or equivalent

# Process B (Java/Scala): Read from shared memory
PlasmaClient client = new PlasmaClient("/tmp/plasma");
ArrowTable table = client.get(object_id);
// → Reads SAME memory, no copy!

Memory usage: 1x (shared between processes)
Transfer time: Microseconds (just mmap)
```

**Case 2: Different Machines (Efficient Serialization, NOT Zero-Copy)**:
```
Machine A (Sender)                  Machine B (Receiver)
     ↓                                      ↓
Arrow Table in memory               Network socket
     ↓                                      ↓
Serialize to IPC format             Receive IPC format
(Arrow IPC/Flight)                  (Arrow IPC/Flight)
     ↓                                      ↓
  ┌──────────────────────┐         ┌──────────────────┐
  │  Network bytes       │  ─────→ │  Network bytes   │
  │  (metadata + buffers)│         │  (metadata + buffers)│
  └──────────────────────┘         └──────────────────┘
                                           ↓
                                    Deserialize to Arrow Table
                                           ↓
                                    Arrow Table in memory

Result: Data copied over network (unavoidable!)
        But serialization/deserialization is cheap
```

**Why Cross-Machine is Still Fast (Even Though Not Zero-Copy)**:

1. **Minimal Serialization Overhead**:
   ```
   Arrow IPC Format = Metadata + Raw Buffers

   Traditional (Pickle/JSON):
     Python objects → Convert each to string/bytes → Encode → Send
     Time: O(n) conversions + O(n) encoding

   Arrow IPC:
     Arrow buffers → Add metadata header → Send raw buffers
     Time: O(1) metadata + O(n) memcpy (unavoidable for network)

   Speedup: No conversion overhead!
   ```

2. **Deserialization is Nearly Free**:
   ```
   Traditional:
     Receive bytes → Parse → Allocate objects → Convert types
     Example (JSON): "123" → parse → create Integer object
     Time: O(n) parsing + O(n) object allocation

   Arrow IPC:
     Receive bytes → Read metadata → Point to buffers
     Already in columnar format, already typed!
     Time: O(1) metadata read + O(n) memcpy (unavoidable)

   Example: 1GB of data
     JSON deserialization: 15 seconds
     Arrow IPC deserialization: 1 second
   ```

3. **Network Transfer is the Real Bottleneck**:
   ```
   1 Gbps network = 125 MB/s

   Sending 1 GB of data:
     Network transfer: ~8 seconds (cannot avoid)
     Arrow serialization: ~0.1 seconds
     Arrow deserialization: ~0.1 seconds
     Total: ~8.2 seconds

   With JSON:
     Network transfer: ~8 seconds (same size after compression)
     JSON serialization: ~10 seconds
     JSON deserialization: ~15 seconds
     Total: ~33 seconds

   Arrow wins because serialization overhead is negligible!
   ```

**Arrow IPC Format Details**:
```
Structure of Arrow IPC message:

┌────────────────────────────────────────┐
│ Message Header (Flatbuffers)          │
│  - Schema (column names, types)       │
│  - RecordBatch metadata               │
│  - Buffer locations and sizes         │
└────────────────────────────────────────┘
┌────────────────────────────────────────┐
│ Buffer 0: Nullability bitmap (column 1)│
│   [compact bit array]                  │
└────────────────────────────────────────┘
┌────────────────────────────────────────┐
│ Buffer 1: Values (column 1)            │
│   [contiguous array of typed values]   │
└────────────────────────────────────────┘
┌────────────────────────────────────────┐
│ Buffer 2: Nullability bitmap (column 2)│
└────────────────────────────────────────┘
┌────────────────────────────────────────┐
│ Buffer 3: Values (column 2)            │
└────────────────────────────────────────┘

Key: Buffers are already in final format!
     Just write to socket, read from socket
     No conversion needed
```

**Arrow Flight (High-Performance RPC)**:
* Built on top of gRPC and HTTP/2
* Optimized for large dataset transfers
* Features:
  * Parallel streams (multiple connections)
  * Authentication and encryption
  * Metadata exchange before data transfer
* Performance: Can saturate 10 Gbps networks

**Example (cross-machine with Arrow Flight)**:
```python
# Server (Machine A)
import pyarrow.flight as flight

class DataService(flight.FlightServerBase):
    def do_get(self, context, ticket):
        # Return large Arrow table
        table = get_data()  # 1 GB table
        return flight.RecordBatchStream(table)

server = DataService()
server.serve()  # Listen on port 8815

# Client (Machine B)
client = flight.FlightClient("grpc://machine-a:8815")
reader = client.do_get(ticket)
table = reader.read_all()  # Efficiently stream Arrow batches

Transfer rate: 500 MB/s (limited by network, not Arrow!)
```

**Summary**:
```
Scenario                  | Mechanism           | Speed
--------------------------|---------------------|------------------
Same process             | Direct pointers     | Instant (no copy)
Different processes      | Shared memory       | Microseconds (mmap)
(same machine)           | (mmap, Plasma)      | TRUE zero-copy
--------------------------|---------------------|------------------
Different machines       | Arrow IPC/Flight    | Network-bound
                         | (network transfer)  | NOT zero-copy
                         |                     | But minimal overhead
```

**Key Insight**:
* Arrow doesn't magically share memory across machines
* Instead: Makes serialization so cheap it's negligible compared to network transfer
* Zero-copy only applies to same-machine, different processes
* Cross-machine: "Zero-overhead" serialization, not zero-copy

**History**:
* **2016**: Project started by Wes McKinney and Jacques Nadeau
  * Wes: Frustrated with Pandas serialization overhead
  * Jacques: CEO of Dremio (needed standard format)
* **2017**: Multiple engines adopt Arrow
  * Spark 2.3 adds Arrow support for Python/R
  * Pandas adds PyArrow integration
* **2020**: Arrow Flight (RPC framework) released
* **2025**: De facto standard for in-memory analytics

**How Velox Uses Arrow**:
* Velox Vectors are **Arrow-compatible** (not identical!)
* Can convert to/from Arrow with zero-copy (when possible)
* Why not use Arrow directly?
  * Need additional encodings (Dictionary, Constant, RLE)
  * Need lazy materialization
  * Need out-of-order writes (for conditionals)
  * Velox = Arrow + optimizations for query engines

### Basic Structure
* Extends Apache Arrow format
* Components:
  * **Size**: Number of rows
  * **Type**: Data type (from type system)
  * **Nullability bitmap**: Optional, for null values
  * **Data buffers**: Actual data storage

### Encoding Formats

#### 1. Flat Encoding
* Standard columnar layout
* Data stored contiguously

#### 2. Dictionary Encoding
* **Structure**:
  ```
  Indices buffer: [0, 2, 1, 0, 2, 1, ...]  (1000 values)
  Inner vector:   ["red", "green", "blue"] (3 values)
  ```
* **Benefits**: Compact representation for low-cardinality columns
* **Optimization**: Operations can be performed on distinct values only

#### 3. Constant Encoding
* All values are the same
* Use cases: Literals, partition keys
* **Structure**: Single value + size

#### 4. Sequence/RLE Encoding
* Run-length encoding for repeated values

#### 5. Bias (Frame of Reference)
* Store offset + deltas for tightly-clustered values

### Lazy Vectors
* **Concept**: Vectors materialized only on first use
* **Use cases**:
  * Joins (may not need all columns)
  * Conditionals in projections
  * Remote storage reads (S3, HDFS)
* **Benefits**:
  * Can avoid entire IO operations
  * Reduce memory usage
* **Callback support**: Pushdown computation without materialization

### Decoded Vector Abstraction
* **Problem**: Input vectors can be arbitrarily encoded
* **Solution**: Unified API that handles all encodings
* **How it works**:
  ```
  Arbitrarily-encoded Vector
    ↓ Decoded Vector
  Flat vector + indices (logically consistent API)
  ```
* **Performance**: Zero-copy for flat, constant, single-level dictionary

### Differences from Apache Arrow

#### 1. String Representation (StringView)
```cpp
struct StringView {
  uint32_t size_;
  char prefix_[4];      // Always stores 4-byte prefix
  union {
    char inlined[8];    // For strings ≤ 12 bytes
    const char* data;   // For strings > 12 bytes
  } value_;
}
```

**Benefits**:
* **Prefix**: Short-circuits failed comparisons (filtering, sorting)
* **Inlining**: Small strings (≤ 12 bytes) don't need secondary buffer
* **Zero-copy operations**: `trim()`, `substr()` just update pointers

**Example**:
```
String "Hello World":
  size_ = 11
  prefix_ = "Hell"
  value_.inlined = "Hello World"  (fully inlined!)

String "A very long string...":
  size_ = 24
  prefix_ = "A ve"
  value_.data = pointer to full string
```

#### 2. Out-of-Order Write Support
* **Use case**: Conditionals (IF, SWITCH)
* **How it works**:
  ```
  Evaluate condition → Generate bitmask
  Process branch 1 → Write to output vector (positions from bitmask)
  Process branch 2 → Write to output vector (other positions)
  ```
* **Support**:
  * Primitive types: Always (constant size)
  * Strings: Yes (StringView is constant 16 bytes)
  * Arrays/Maps: Store both lengths and offsets buffers

#### 3. Additional Encodings
* RLE (Run-Length Encoding)
* Constant encoding

### Vector Conversion to Arrow
* Zero-copy when possible
* Re-arranges data when needed
* API provided for interoperability

## Expression Evaluation

### Expression Tree Nodes
* **Column reference**: Reference to input column
* **Constant/Literal**: Fixed value
* **Function call**: Function name + input expressions
* **CAST**: Type conversion
* **Lambda function**: For higher-order functions

### Metadata
* **Determinism**: Same inputs → same outputs?
* **Null propagation**: Any null input → null output?

### Two-Phase Process

#### Phase 1: Compilation

**1. Common Subexpression Elimination (CSE)**
```sql
Expression: strpos(upper(a), 'FOO') > 0 OR strpos(upper(a), 'BAR') > 0

Identified common subexpression: upper(a)
Result: Calculated only once, reused twice
```

**2. Constant Folding**
```sql
Before: upper(a) = upper('Foo')
After:  upper(a) = 'FOO'  (evaluated at compile time)
```

**3. Adaptive Conjunct Reordering**
* **For AND/OR expressions**:
* Track performance of each conjunct
* Evaluate most selective first
* **Metric**: `time / (1 + n_in - n_out)` (lower is better)
* **Also flattens nested AND/OR**:
  ```
  Before: AND(AND(AND(a, b), c), AND(d, e))
  After:  AND(a, b, c, d, e)
  ```

#### Phase 2: Evaluation

**1. Null Propagation Optimization**
* If expression propagates nulls and any input is null:
  * Just combine nullability bitmasks (SIMD)
  * Skip evaluation entirely

**2. Peeling (Dictionary Optimization)**
```
Dictionary-encoded input:
  Indices: [0, 1, 2, 0, 1, 2, ...] (1000 rows)
  Inner:   ["red", "green", "blue"] (3 values)

Evaluation of upper(color):
  1. Peel off dictionary wrapper
  2. Apply upper() to 3 distinct values: ["RED", "GREEN", "BLUE"]
  3. Wrap result with original indices

Result: 3 function calls instead of 1000!
```

**3. Memoization**
* Remembers results for base vectors across batches
* Use case: Same dictionary base vector reused in multiple batches
```
Batch 1: Dict with base ["red", "green", "blue"]
  → Compute upper() → Cache result

Batch 2: Dict with same base, different indices
  → Reuse cached result → Just wrap with new indices
```

**Benefits**:
* Huge speedup for complex operations:
  * String manipulation
  * Regular expressions
  * Array/map operations
  * Nested data traversal

### Code Generation (Experimental)
* **Approach**: Rewrite expression tree as C++ source
* **Compilation**: Use gcc/clang to compile to shared library
* **Overhead**: 10+ seconds compilation time
* **Target use cases**:
  * Large ETL queries (hours to days)
  * Fixed expression trees (e.g., feature engineering)
* **Open questions**:
  * Codegen vs vectorized tradeoffs
  * Codegen vs JIT LLVM
  * Runtime adaptivity between paths

## Functions

### Scalar Functions

#### Vectorized API
* **Input**: Full Vectors (batches)
* **Output**: Full Vector
* **Direct access to**:
  * Encoding formats
  * Nullability buffers
  * Active rows bitmap
* **Pros**: Can leverage columnar layout for constant-time operations
* **Cons**: Complex, error-prone, high cognitive burden

**Examples of constant-time functions**:
```cpp
is_null()       → Return nullability buffer
cardinality()   → Return lengths buffer (for arrays)
map_keys()      → Return keys buffer (for maps)
map_values()    → Return values buffer (for maps)
```

#### Simple API
* **Goal**: Developer productivity and ease of use
* **Input**: Single row values (NOT Vectors)
* **Output**: Single value
* **Hide**: Encoding, nullability, memory layout

**Example**:
```cpp
class MultiplyFunction {
  void call(
    int64_t& result,           // Output (by reference)
    const int64_t& a,          // Input 1
    const int64_t& b) {        // Input 2
    result = a * b;
  }
};

registerFunction<
  MultiplyFunction,
  int64_t,   // Return type
  int64_t,   // Arg 1 type
  int64_t    // Arg 2 type
>({"multiply"});
```

**Features**:
* **Return**: `void` (never null) or `bool` (true = not null)
* **Default null behavior**: Any null input → null output (skip call)
* **Custom null behavior**: Provide `callNullable()` with pointers

**How it works**:
* Uses `DecodedVector` to handle any encoding
* C++ template metaprogramming for efficient batching
* **Inlines** all logic in hot loop (no function call overhead)
* Compilers can auto-vectorize (generate SIMD code!)

**Performance**:
```
Micro-benchmark results:
  plus():      Simple API = Vectorized API (no overhead!)
  make_map():  Simple API faster (auto-optimizations)
  array_min(): Simple API faster (missed optimizations in vectorized)
```

**Type Mapping**:
* Primitives → C++ types (int64_t, double, etc.)
* Strings → Proxy objects (not std::string, zero-copy)
* Arrays → ArrayReader/ArrayWriter (std::vector-like API)
* Maps → MapReader/MapWriter
* Structs → RowReader/RowWriter

#### Advanced String Processing

**1. ASCII Fast Path**
* **Observation**: Most warehouse strings are ASCII-only
* **Optimization**: Provide `callAscii()` method
* **Engine**: Automatically calls when inputs are ASCII
* **Declaration**: Set ASCII behavior flag (output ASCII if inputs ASCII)

**Performance gains**:
```
Function      Without ASCII opt    With ASCII opt
lower()       10,000 ns            500 ns
upper()       10,000 ns            500 ns
substr()      8,000 ns             300 ns
strpos()      1,500 ns             500 ns
```

**2. Zero-Copy String Operations**
* **Use case**: `substr()`, `trim()`, `split()`
* **Mechanism**: Set flag to reuse input string buffer in output
* **How**: Output StringView points to input buffer (no copy!)

**Performance**:
```
substr() implementations:
  NoOpts (baseline):           100 ns
  ASCII-only:                   50 ns
  ASCII-only + buffer reuse:    20 ns
```

### Aggregate Functions

#### Execution Steps
1. **Partial aggregation**: Raw data → Intermediate results
2. **Final aggregation**: Intermediate → Final results
3. **Single aggregation** (optional): When pre-partitioned on grouping keys
4. **Intermediate aggregation** (optional): Combine partial results

#### Accumulator Types

**1. Fixed-Size Accumulators**
* Functions: `count()`, `sum()`, `avg()`, `min()`, `max()`
* **Storage**: Inline within hash table row
* **Example**:
  ```
  Hash table row:
  [grouping_key | count | sum | avg_sum | avg_count]
  ```

**2. Variable-Size Accumulators**
* Functions: `array_agg()`, `distinct()`, approximate percentiles
* **Storage**: Separate buffer, pointer stored in row
* **Example**:
  ```
  Hash table row:
  [grouping_key | pointer_to_accumulator_buffer]
  ```

## Operators

### Execution Model

#### Task, Pipeline, Driver
```
Task (query plan fragment)
  ↓
Divided into Pipelines (linear sub-trees)
  ↓
Each Pipeline → Multiple Drivers (threads of execution)

Example:
  HashJoin splits into:
    - Pipeline 1: HashBuild
    - Pipeline 2: HashProbe
```

**Driver Characteristics**:
* Can go on/off thread based on work availability
* Reasons to go off-thread:
  * Consumer hasn't consumed data yet
  * Source hasn't produced data
  * Waiting for file scans
* More convenient than Volcano iterator model (state is resumable)

#### Operator API
* `addInput()`: Add batch of vectors
* `getOutput()`: Get batch of vectors
* `isReady()`: Ready to accept more input?
* `noMoreInput()`: Signal end of input (flush state)

### TableScan, Filter, Project

#### Filter Execution
* **Column-by-column processing**: Filter columns first
* **Adaptive filter ordering**:
  ```
  Metric: time / (1 + values_in - values_out)

  Choose filter that drops most values in least time
  ```
* **SIMD for simple filters**:
  * Process multiple values per CPU clock with AVX2
  * Integer comparisons ~1 hit per clock

#### Dictionary-Encoded Filters
* **Cache filter results** (memoization as in expression eval)
* **SIMD cache lookup**:
  * Gather values
  * Compare against cache
  * Permute to write passing rows
  * > 1 hit per CPU clock

#### Large IN Filters
* For hash join pushdown
* Trigger 4 cache misses at a time (memory-level parallelism)

#### FilterProject Optimization
* **Single expression context** for all filter + project expressions
* **Execution order**:
  1. Evaluate filter on all rows
  2. If no rows pass → **skip project expressions entirely**
  3. Else → evaluate projects only on passing rows

### Hash Table for Joins and Aggregations

#### VectorHasher
* **Purpose**: Process hashing keys in columnar manner
* **Adaptivity**: Recognizes key characteristics
  ```
  If keys map to small integer range:
    → Flat array (direct indexing)

  Else if multiple keys can map to single 64-bit key:
    → Single normalized key
    If range small:
      → Flat array
    Else:
      → Hash table with single key

  Else:
    → Multi-part hash key (less efficient)
  ```
* **Dynamic**: Can change as more data is processed
* **Pushdown**: VectorHashers can be pushed to TableScans as IN filters

#### Hash Table Layout
* **Similar to Meta's F14** hash table
* **Memory access interleaving**:
  * Lookups for different keys interleaved
  * Maximize cache misses in-flight simultaneously
  * Reduce pipeline stalls
* **Storage**: Row-wise (minimize cache misses for dependent data)

### Memory Management

#### Memory Pools
* **Hierarchical tracking** of memory usage
* **Allocation types**:
  * Small objects (plans, expressions) → C++ heap
  * Large objects (cache, hash tables, buffers) → Custom allocator

#### Custom Allocator
* **Zero fragmentation** for large objects
* Uses `mmap` and `madvise` (similar to Umbra)
* **Memory tracking**: All allocations through pools tracked
* **Limit enforcement**: Per-pool limits

#### Memory Reservation
* **Purpose**: Guarantee budget for specific operation
* Example: Processing batch of group-by keys

#### Recovery Mechanisms

**1. Pause and Resume**
* Consumers can be **asynchronously paused**
* Consumer acknowledges, goes off-thread
* Returns continuation future for resumption
* While paused: Task can be instructed to spill or cancel

**2. Memory Arbiter**
* **Process-wide** visibility over all tasks
* Tracks:
  * Memory usage per task
  * Reclaimable memory (how much could be freed by spilling)
* **Pluggable logic**: Which task to spill/cancel?

**3. Spilling Interface**
* Operators implement:
  * `reclaimableMemory()`: How much could be released?
  * `spill()`: Actual spilling method
* If not implemented: Operator must continue without extra memory or fail

**4. Adaptive Resource Management**
* Operators monitor memory pressure
* Example: Exchange operator reduces buffer size when memory scarce

#### Caching (Memory + SSD)

**Architecture**:
```
Disaggregated Storage (S3, HDFS)
         ↓ Read
    Memory Cache (all unused RAM)
         ↓ Evict
      SSD Cache (local disk)
```

**Memory Cache**:
* **Allocation**: All memory not used otherwise
* **Buffer sizes**: Arbitrary (match columnar dataset layout)
* No fragmentation (mmap/madvise)

**Read Coalescing**:
* Merge nearby column reads if gap is small
* **Thresholds**:
  * SSD: ~20KB gap
  * Disaggregated storage: ~500KB gap
* **Benefit**: Temporal locality → correlated columns cached together

**Adaptive Prefetching**:
* Track column access frequencies per-query
* Prefetch hot columns in advance
* **Result**: Interleave IO stalls with CPU processing
* Many workloads effectively served from memory (IO off critical path)

**Performance** (26-core, 64GB RAM, 2x2TB SSD):
```
Storage Layer          Read Rate
RAM cache             8 GB/s
SSD cache             2-3 GB/s
Disaggregated (S3)    700 MB/s

Speedup:
  RAM vs SSD:              ~3x
  SSD vs Disaggregated:    ~4x
  RAM vs Disaggregated:    ~12x
```

## Experimental Results

### TPC-H (80 nodes, 64GB RAM, 2x2TB SSD, 3TB dataset)

**Setup**:
* Prestissimo (Velox C++) vs Presto Java
* Warm cache on both
* ORC format, no compression
* Optimized join trees

**Results**:
```
Query    Wall Time (sec)     CPU Time (sec)      Workload Type
         C++   Java  Speedup  C++    Java  Speedup

Q1       5     42    8.4x     2211   14435  6.5x   CPU-bound
Q6       1     9     9.0x     538    2018   3.7x   CPU-bound
Q13      15    31    2.0x     5647   12322  2.1x   Shuffle-heavy
Q19      6     13    2.1x     1362   3483   2.5x   Shuffle-heavy
```

**Observations**:
* CPU-bound: **~9x speedup**, now bottlenecked on coordinator
* Shuffle-heavy: **~2x speedup**, bottlenecked on shuffle latency

### Real Production Workloads

**Setup**:
* Replay production traffic from interactive analytical tools
* Two identical clusters (Prestissimo vs Presto Java)

**Results**:
* **Average speedup**: 6-7x
* **Many queries**: 10x or more speedup
* Distribution histogram shows wide range (0x to 10x+)

### Capacity Impact
**Experiment**: Shadow production workloads, reduce Prestissimo cluster size

**Result**: **3x fewer servers** (60 → 20) for same workload with equal/better performance

**Implications**:
* Significant datacenter power savings
* Lower hardware costs
* Smaller operational footprint

## Lessons and Future Directions

### Key Insights

#### 1. Siloed Engines Can Be Unified
* Velox integrated with 12+ systems at Meta:
  * Analytics: Presto, Spark
  * Stream processing: XStream
  * Messaging: Scribe
  * Ingestion: FBETL
  * ML: PyTorch (TorchArrow), F3
  * And more
* **Proof point**: Unified execution engine is achievable

#### 2. Modularity Enables Reusability
* Engines pick components they need
* Simple cases: Just Type, Vector, Serializer
* Full SQL engine: All operators + resource management

#### 3. Extensibility is Critical
* Generic components in library
* Engine-specific plugins in engine codebase
* Examples:
  * Generic: ORC/Parquet, common operators
  * Engine-specific: ML functions, stream operators

### Emerging Trends

#### 1. AI as Primary Data Consumer
* ML workloads dominate data processing
* Need for unified Data Analytics + ML infrastructure
* TorchArrow demonstrates viability

#### 2. Hardware Componentization
* GPUs, FPGAs, tensor accelerators
* Cache-coherent interconnects (CXL)
* Future: Specialized kernels plugged into data management "bus"

#### 3. Platform Evolution
* Apache Arrow: Standardized in-memory format
* Substrait: Interoperable plan representation
* **Velox**: Execution engine layer
* **Vision**: Plug-and-play specialized processing kernels

### Open Questions and Future Work

#### 1. Codegen Trade-offs
* When does codegen outweigh compilation delays?
* Codegen vs JIT LLVM compilation?
* Runtime adaptivity between vectorized and codegen paths?

#### 2. Low-Latency Workloads
* Operational databases
* Small batch sizes
* Vectorization overhead for single rows
* Solutions under investigation

#### 3. Local Intelligence and Adaptivity
* Less reliance on omniscient optimizer
* Emphasis on local adaptivity at all stack levels
* Auto-configuration and self-driven systems

#### 4. One Engine for All Workloads?
* Batch/ETL, interactive analytics, stream processing
* Transactional, AI/ML, and more
* Single extensible open source engine
* **Challenge**: "One size does not fit all" but with adaptivity

## Key Insights

### Technical Innovations

#### 1. Vectorization + Adaptivity
* Process data in columnar batches
* Adapt to data characteristics at runtime
* Dictionary encoding, memoization, peeling

#### 2. Developer Productivity
* Simple function API hides complexity
* Same performance as hand-optimized vectorized code
* Compiler auto-vectorization (SIMD generation)

#### 3. Memory and Resource Management
* Zero-fragmentation allocator (mmap/madvise)
* Hierarchical memory tracking
* Spilling and caching support
* Adaptive prefetching

#### 4. Consistent Semantics
* Same function behavior across all engines
* End of "12 different substr() implementations"
* Users can transfer knowledge between systems

### Strategic Impact

#### 1. Engineering Efficiency
* Features developed once, maintained once
* Eliminates duplication across 12+ systems
* Faster innovation (deploy to all engines at once)

#### 2. Hardware Partnerships
* Single integration point for hardware vendors
* New hardware optimizations benefit all engines
* Example: GPUs, accelerators, CXL devices

#### 3. Research Collaboration
* Open source enables academic partnerships
* Unified platform for testing new ideas
* Ideas deployed to production at scale
