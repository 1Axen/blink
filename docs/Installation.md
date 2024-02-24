# Navigation
[Home](https://github.com/1Axen/Blink/blob/main/README.md)  
[Installation](https://github.com/1Axen/Blink/blob/main/docs/Installation.md)  
[Getting Started](https://github.com/1Axen/Blink/blob/main/docs/Getting-Started.md)  
[Using Blink](https://github.com/1Axen/Blink/blob/main/docs/Using.md)  
[Studio Plugin](https://github.com/1Axen/Blink/blob/main/docs/Plugin.md)
# Installation
## From Aftman
> [!NOTE]  
> The aftman version of Blink currently only supports windows x86 and x64.
```bash
aftman add 1Axen/Blink
```
## From GitHub Releases
Download the standalone executable from [Github Releases](https://github.com/1Axen/Blink/releases).
## From Bytecode
Alternative you can run blink from bytecode using line.
You can download the packaged bytecode from [Github Releases](https://github.com/1Axen/Blink/releases).
## Studio Plugin
Blink offers a companion studio plugin which allows you to write and generate files within Studio without the need for external tooling.
You can download the latest plugin from [Github Releases](https://github.com/1Axen/Blink/releases).
For more information on how to use it head over to [Studio Plugin](https://github.com/1Axen/Blink/blob/main/docs/Plugin.md).
### Installing lune
Blink uses lune as it's runtime enviornment, you can install lune using aftman:
``` 
aftman add filiptibell/lune
```
### Running bytecode
Open the directory in which you unzipped the bytecode and run the following command:
```
lune init [INPUT]
```
## Plugin Marketplace
Coming soon!