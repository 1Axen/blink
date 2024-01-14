# Navigation
[Home](https://github.com/1Axen/Blink/blob/main/README.md)  
[Installation](https://github.com/1Axen/Blink/blob/main/docs/Installation.md)  
[Getting Started](https://github.com/1Axen/Blink/blob/main/docs/Getting-Started.md)  
[Writing network descriptions](https://github.com/1Axen/Blink/blob/main/docs/Using.md)
# Getting Started
## Write your first network description
If you're looking for an example you can check out the [source file](https://github.com/1Axen/Blink/blob/main/test/Source.txt) used for testing.  
For a guide on the syntax of Blink head over to [Writing network descriptions](https://github.com/1Axen/Blink/blob/main/docs/Using.md).
## Generating code
Blink currently only supports code generation through CLI.  
To generate output code run the following command in the directory in which you installed Blink:
```
blink [INPUT]
``` 
## Using the generated code
When requiring the code generated it will return a table which contains all defined events & functions, you can use this table to fire/invoke and listen to events/functions.
```lua
local Blink = require(PATH_TO_MODULE)

--> Firing events
Blink.Example.Fire(1)
Blink.Example.FireAll(1)
Blink.Example.FireList(List, 1)
Blink.Example.FireExcept(Player, 1)

--> Listening to events
Blink.AnotherExample.Listen(function(...)
    print(...)
end)
```

