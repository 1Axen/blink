# Navigation
[Home](https://github.com/1Axen/DeclareNet/blob/main/README.md)  
[Installation](https://github.com/1Axen/DeclareNet/blob/main/docs/Installation.md)  
[Getting Started](https://github.com/1Axen/DeclareNet/blob/main/docs/Getting-Started.md)  
[Writing network descriptions](https://github.com/1Axen/DeclareNet/blob/main/docs/Using.md)
# Getting Started
## Write your first network description
If you're looking for an example you can check out the [source file](https://github.com/1Axen/DeclareNet/blob/main/test/Source.txt) used for testing.  
For a guide on the syntax of DeclareNet head over to [Writing network descriptions](https://github.com/1Axen/DeclareNet/blob/main/docs/Using.md).
## Generating code
DeclareNet currently only supports code generation through CLI.  
To generate output code run the following command in the directory in which you installed DeclareNet:
```
lune init [PATH_TO_SOURCE]
``` 
## Using the generated code
When requiring the code generated it will return a table which contains all defined packets, you can use this table to fire and listen to packets.
```lua
local DeclareNet = require(PATH_TO_MODULE)

--> Firing packets
DeclareNet.Example.Fire(1)
DeclareNet.Example.FireAll(1)
DeclareNet.Example.FireList(List, 1)
DeclareNet.Example.FireExcept(Player, 1)

--> Listening to packets
DeclareNet.AnotherExample.Listen(function(...)
    print(...)
end)
```

