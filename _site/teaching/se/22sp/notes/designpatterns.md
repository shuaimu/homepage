* What is a design pattern?
  * summarize an idiom / convention in OO programmning
* What is (pure) OO programming? 
  * everything is an object (including basic types)
  * functions are second-class citizens
    * functions cannot be used as parameters or variables
  * e.g., smalltalk
    * inspires many other languages, Objective-C, Ruby, etc.
* How to understand a pattern?
  * Problem to be solved, or intent
  * What is the solution?
  * Give an example?
* What are a few typical design patterns?
  * Factory
    * Problem: new is not flexible enough
    * Solution: create object in a different place called "Factory"
    * Example: 
      * coffee been -> coffee 
      * in RPC, or extending Bitcoin to multiple coins
  * Adapter
    * Problem: mismatching interface
    * Solution: add an adapting function
    * Example: 
      * medium -> grande 
      * xml -> json 
  * Iterator  
    * Problem: iterate throuh a container
    * Solution: add a structure independent indicator 
    * Example: trivial 
* Categorize  
  * By juristidiction 
  * By characterization
    * creational
    * structural
    * behavioral 
* Creational
  * Abstract Factory
    * e.g., cross platform gui
  * Builder
    * e.g., organize complex steps
      * Step 1: Measure for your brew ratio. ...
      * Step 2: Grind the coffee. ...
      * Step 3: Boil the water and wait 1 minute. ...
      * Step 4: Place and wet the filter. ...
      * Step 5: Place the coffee in the filter. ...
      * Step 6: Pour and wait. ...
      * Step 7: Continue and complete your pour. ...
      * Step 8: Enjoy your coffee!
* Structural
  * Bridge 
    * e.g., coffee size * sugar * milk 
    * e.g., the logger
  * Proxy 
    * buy from different coffee shop
    * e.g., rpc
* Behavioral
  * Observer
    * e.g., UI
  * Command
  * Template method
    * put an elephent to fridge  
      * Step 1: open the door
      * Step 2: put the elephent in 
      * Step 3: close the door
* Rethinking
  * What if we have function variables (lambdas)?