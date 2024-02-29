# Navigation
[Home](https://github.com/1Axen/Blink/blob/main/README.md)  
[Installation](https://github.com/1Axen/Blink/blob/main/docs/Installation.md)  
[Getting Started](https://github.com/1Axen/Blink/blob/main/docs/Getting-Started.md)  
[Using Blink](https://github.com/1Axen/Blink/blob/main/docs/Using.md)  
[Studio Plugin](https://github.com/1Axen/Blink/blob/main/docs/Plugin.md)
# Options
Options go at the top of a source file and are used to configure the output of Blink.
```
option [OPTION] = [VALUE]
```
## `Casing`
Default: `Pascal`  
Options: `Pascal`, `Camel`, `Snake`  
Controls the casing with which event/function methods generate.
```
option Casing = Camel
```
## `ServerOutput`, `ClientOutput`, `TypesOutput`
These options allow you to specify where Blink will generate files.
```
option TypesOutput = "../Network/Types.luau"
option ServerOutput = "../Network/Server.luau"
option ClientOutput = "../Network/Client.luau"
```
## `FutureLibrary` and `PromiseLibrary`
In order to use future and promise yield types with functions a path to each library used must be specified  
```
option FutureLibrary = "ReplicatedStorage.Packages.Future"
option PromiseLibrary = "ReplicatedStorage.Packages.Promise"
```
## `ManualReplication`
Default: `false`  
Controls wether Blink will replicate events and functions automatically at the end of every frame.  
When set to `true` automatic replication will be disabled and instead a `StepReplication` function will be exposed.
# Basic syntax and supported types
You can mark any type as optional by appending `?` after it
## Primitives
You can define a primitive using the `type` keyword  
Blink supports the following primitives:  

|Name    |Size (Bytes)|Supports ranges  |Minimum        |Maximum      | 
|--------|------------|-----------------|---------------|-------------|
|u8      |1 Byte      |Yes              |0              |255          |
|u16     |2 Bytes     |Yes              |0              |65,535       |
|u32     |4 Bytes     |Yes              |0              |4,294,967,295|
|i8      |1 Byte      |Yes              |-128           |127          |
|i16     |2 Bytes     |Yes              |-32,768        |32,767       |
|i32     |4 Bytes     |Yes              |-2,147,483,648 |2,147,483,647|
|f16     |2 Bytes     |Yes              |-65504         |65504        |
|f32     |4 Bytes     |Yes              |−16777216      |16777216     |
|f64     |8 Bytes     |Yes              |-2^53          |2^53         |
|vector  |12 Bytes    |Yes (Magnitude)  |N/A            |N/A          |
|buffer  |N/A         |Yes (buffer.len) |N/A            |65,535 Bytes |
|string  |N/A         |Yes (string.len) |N/A            |65,535 Bytes |
|boolean |1 Byte      |No               |N/A            |N/A          |
|CFrame  |24 Bytes    |No               |N/A            |N/A          |
|Color3  |12 Bytes    |No               |N/A            |N/A          |
|Instance|4 Bytes     |No               |N/A            |N/A          |
|unknown |N/A         |No               |N/A            |N/A          |

Arrays can be defined by appending `[SIZE]` or `[[MIN]..[MAX]]` after the type declaration
Primitives can be constrained to ranges by writing `([MIN]..[MAX])` after the primitive type. Ranges are inclusive.  
```
type Simple = u8
type Optional = u8?
type Array = u8[1]
type Range = u8[0..100]
map Players = {[u8]: Instance(Player)}[0..255]
enum States = (A, B, C, D)[0..255]
struct Dictionary {
    Field: u8
}[0..255]
```
## Enums
You can define enums using the `enum` keyword  
```
enum State = { Starting, Started, Stopping, Stopped }
```
## Structs
You can define structs using the `struct` keyword  
Structs can also hold structs within.  
```
struct Entity {
    Identifier: u8,
    Health: u8(0..100),
    State: ( Dead, Alive )?,
    Direction: vector(0..1),
    Substruct: {
        Empty: u8[0],
        Complex: u8[1..12],
        Vector: UnitVector,
    }?
}
```
## Maps
You can define maps using the `map` keyword   
> [!NOTE]
> Maps cannot currently have maps as keys or values.  
> You also cannot have optional keys or values as there is no way to represent those in Luau.
```
map Example = {[string]: u8}
```
## Instances
Instances are another type of Primitive and as such they can be defined using the `type` keyword  
```
type Example = Instance
type Example = Instance(ClassName) -- You can also specify instance class
```
> [!WARNING]
> If a non optional instance results in nil on the recieving side it will result in an error, this may be caused by various things like streaming, players leaving etc.  
> In order to get around this you must mark instances as **optional**.
## Tuples
Tuples can be defined using brackets `()`.  
**Tuples can only be defined within the data field of an event/function.**  
``` 
event Example {
    From: Server,
    Type: Reliable,
    Call: SingleSync,
    Data: (u8, u16?, Instance, Instance?, u8[8])
}
```
## Events
You can define events using the `event` keyword  
Events have 4 fields:  
`From` - `Client` or `Server`  
`Type` - `Reliable` or `Unreliable`  
`Call` - `SingleSync` or `SingleAsync`  
`Data` - Can hold either a type definition or a reference to an already defined type  
```
event Simple {
    From: Client,
    Type: Unreliable,
    Call: SingleSync,
    Data: u8
}

event Reference {
    From: Client,
    Type: Unreliable,
    Call: SingleSync,
    Data: Entity
}

event Complex {
    From: Client,
    Type: Unreliable,
    Call: SingleSync,
    Data: {
        Field = u8
    }
}
```
## Functions
You can define functions using the `function` keyword  
Functions have 3 fields:  
`Yield` - `Coroutine` or `Future` or `Promise`    
Deifnes what library will be used to handle invocations  
`Data` - Can hold either a type definition or a reference to an already defined type  
`Return` - Can hold either a type definition or a reference to an already defined type 
```
function Example {
    Yield: Coroutine,
    Data: u8,
    Return: u8
}

function ExampleFuture {
    Yield: Future,
    Data: u8,
    Return: u8
}

function ExamplePromise {
    Yield: Promise,
    Data: u8,
    Return: u8
}
```
# Scopes (Namespaces)
You can define a scope (namespace) using the `scope` keyword  
Scopes allow you to group similiar types together for further organization  

Defining scopes:  
```
scope ExampleScope {
    type InScopeType = u8
    event InScopeEvent {
        From: Server,
        Type: Reliable,
        Call: SingleSync,
        Data: u8
    }
}

struct Example {
    Reference = ExampleScope.InScopeType
}
```

Using scopes in code:  
```lua
local Blink = require(PATH_TO_BLINK)
Blink.ExampleScope.InScopeEvent.FireAll(0)

local Number: Blink.ExampleScope_InScopeEvent = 0
```
# Limitations
## Referencing types
A type must be defined earlier in the source for it to be referenceable, you cannot reference a type before it has been defined.
```
struct Invalid {
    Field: Number
}
type Number = u8
```
```
[ERROR]
    |
002 |     Field = Number
    |             ^^^^^^ Unknown type referenced.
```
## Keywords
You cannot use any keywords as "Identifiers".
```
type struct = {}
```
```
[ERROR]
    |
001 | type struct = {
    |      ^^^^^^ Unexpected token: "Keyword", expected: "Identifier".
```
