# Tor: The Onion Routers

## Unsafe communication
* data: content ("what") can be intercepted
  * this can be solved by encryption.
* metadata: source ("who") is known by any router on the link
  * metadata leak in some cases has severe outcome
  * this is harder to protect.
 
## Tor
* goal: mask identity of source  
* assumptions 
  * trusted: directory server that has the information of the routers
  * untrusted: a router can be hostile, but as long as one router is "good", the communication is safe
* Protocol 
  * the user contacts the directory server and selects a set of routers.
  * the user establishes a communication link ("circuit") hop by hop. each router is only aware of the prior router on the circuit. 
  * when the user sends a message over the circuit, the message should be encrypted in layers. Each hop only knows the key to decrypt its own layer.   
  * Each circuit is multiplexed by multiple TCP streams. (why? because establishing a circuit costs time.)
* main idea, layered encryption over a circuit of onion routers (OR) 
  * the client chooses a circuit: a set of routers as a link (why cannot a router choose?)
  * for each OR on the circuit, the client shares a key with the OR. e.g., if the circuit has two routers r1 and r2.       
    * r1 has K1, r2 has K2
    * client has both K1 and K2
    * client encrypts the message like \{\{msg, dst\}_K2\}, r2\}_K1, and send it to r1
* how can the network be transparent to applications?
  * e.g., web browsers and web servers
  * both the server and client uses a proxy

## Creating circuits dynamically 
* background: shared secret
  * each party generates a pub/pri key pair 
  * share the pub key with each other
  * use the other's public key and its own private key to generates the same result 
  * use the result as a shared key. 
* incrementally create a circuit
  * first add r1
  * then ask r1 to add r2
  * repeat the above process until get all routers in the circuit 
  * between each pair of routers, circ-id changes to avoid leak of info  
* Tor uses this to establish the key for symmetric encryption. (Why not use public/private key scheme? Because it may leak the user's identity.)

## Possible attacks
* if we can hack into all the routers on a circuit in the order from the destination to the source, we're able to find the source.
* the attack can also be done by hijacking the network traffic of all routers on the circuit. 

