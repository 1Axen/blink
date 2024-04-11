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
## `WriteValidations`
Default: `false`
Controls if Blink will check types when writing them (firing an event/invoking a function). Helpful for debugging and during development, but it might result in degraded performance. It is encouraged you disable this option in production.
> [!TIP]
> Blink only checks for builtin primitives. For example if a number was passed. More complicated types like structs, maps and enums cannot be validated.
## `ManualReplication`
Default: `false`  
Controls if Blink will replicate events and functions automatically at the end of every frame.  
When set to `true` automatic replication will be disabled and a `StepReplication` function will be exposed instead.
# Basic syntax and supported types
You can mark any type as optional by appending `?` after it
## Primitives
You can define a primitive using the `type` keyword  
Blink supports the following primitives:  

|Name    |Size (Bytes)|Supports ranges  |Minimum        |Maximum      |Components| 
|--------|------------|-----------------|---------------|-------------|----------|
|u8      |1 Byte      |Yes              |0              |255          |No        |
|u16     |2 Bytes     |Yes              |0              |65,535       |No        |
|u32     |4 Bytes     |Yes              |0              |4,294,967,295|No        |
|i8      |1 Byte      |Yes              |-128           |127          |No        |
|i16     |2 Bytes     |Yes              |-32,768        |32,767       |No        |
|i32     |4 Bytes     |Yes              |-2,147,483,648 |2,147,483,647|No        |
|f16     |2 Bytes     |Yes              |-65504         |65504        |No        |
|f32     |4 Bytes     |Yes              |−16777216      |16777216     |No        |
|f64     |8 Bytes     |Yes              |-2^53          |2^53         |No        |
|vector  |12 Bytes    |Yes (Magnitude)  |N/A            |N/A          |Yes (1)   |
|buffer  |N/A         |Yes (buffer.len) |N/A            |65,535 Bytes |No        |
|string  |N/A         |Yes (string.len) |N/A            |65,535 Bytes |No        |
|boolean |1 Byte      |No               |N/A            |N/A          |No        |
|CFrame  |24 Bytes    |No               |N/A            |N/A          |Yes (2)   |
|Color3  |12 Bytes    |No               |N/A            |N/A          |No        |
|Instance|4 Bytes     |No               |N/A            |N/A          |No        |
|unknown |N/A         |No               |N/A            |N/A          |No        |

### Attributes
A type can be marked optional by appending `?` at the end.

Arrays can be defined by appending `[SIZE]` or `[[MIN]..[MAX]]` after the type declaration.  

Primitives can be constrained to ranges by writing `([MIN]..[MAX])` after the primitive type. Ranges are inclusive.  

Components can be specified using the angled brackets `<>`, they allow you to specify what numerical type (`u8`, `u16`, `u32`, `i8`, `i16`, `i32`, `f16`, `f32`, `f64`) to use for `vector` and `CFrame` axes.  
For example `vector<i16>` will define a vector that represents its axes using `i16`.  
CFrames take two components `CFrame<f32, f32>`, one representing position and one representing rotation in order.
> [!WARNING]
> Using non float types for CFrame will result in the rotation being reset to 0.
```
type Simple = u8
type Optional = u8?
type Array = u8[1]
type Range = u8[0..100]
type VectorInt16 = vector<int16>
type Orientation = CFrame<int16, f16>
map Players = {[u8]: Instance(Player)}[0..255]
enum States = (A, B, C, D)[0..255]
struct Dictionary {
    Field: u8
}[0..255]
```
## Enums
You can define enums using the `enum` keyword.  
Blink has two type of enums, unit and tagged enums.
### Unit Enums
Unit enums represent a set of possible values.  
For example, a unit enum representing the state of a car engine:
```
enum State = { Starting, Started, Stopping, Stopped }
```
### Tagged Enums
Tagged enums represent a set of possible variants with some data attached to each.  
They are defined using a string which represents the tag field name.  
Each variant is defined by a tag, followed by a struct.  
```
struct Vector2 {
    X: u16,
    Y: u16
}

enum Buttons = {Left, Right, Middle}
enum MouseEvent = "Type" {
    Move {
        Delta: Vector2,
        Position: Vector2,
    },
    Drag {
        Delta: Vector2,
        Position: Vector2
    },
    Click {
        Button: Buttons,
        Position: Vector2
    },
}
```
## Structs
You can define structs using the `struct` keyword  
Structs can also hold structs within:
```
struct Entity {
    Identifier: u8,
    Health: u8(0..100),
    State: ( Dead, Alive )?,
    Direction: vector(0..1),
    Substruct: struct {
        Empty: u8[0],
        Complex: u8[1..12],
        Vector: UnitVector,
    }?
}
```
### Generics
---
Structs, tagged enums and maps support the use of generic type parameters, a generic is simply a type which allows you to slot in any other type, generics can be very handy in reducing repetition.
```
struct Packet<T> {
    Sequence: u16,
    Ack: u16,
    Data: T
}

struct Entity {
    Identifier: u8,
    Health: u8(0..100),
    Angle: u16,
    Position: vector
}

struct Command {
    X: u8,
    Y: u8,
    Z: u8,
    -- ...
}

event Snapshot {
    From: Server,
    Type: Unreliable,
    Call: SingleSync,
    Data: Packet<Entity[]>
}

event Command {
    From: Server,
    Type: Unreliable,
    Call: SingleSync,
    Data: Packet<Command>
}
```
In the code above we have a simple packet transmission protocol which contains the current packets identifier (Sequence), the last recieved packet (Ack) and a generic data field. Instead of repeating the contents of `Packet` everytime we need to send something over the wire we can take advantage of generics to automatically fill the `Data` field with whatever we need to transmit.
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
    Data: struct {
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
---
Scopes automatically inherit any declarations made within their parent scopes (including main)  
```
type Example = u8
scope ExampleScope {
    type TypeInScope = u8
    scope ExampleNestedScope {
        -- Example is taken from the main (global) scope
        -- TypeInScope is taken from the parent scope (ExampleScope)
        map ExampleMap = {[Example]: TypeInScope}
    }
}
---
Using scopes in code:  
```lua
local Blink = require(PATH_TO_BLINK)
Blink.ExampleScope.InScopeEvent.FireAll(0)

local Number: Blink.ExampleScope_InScopeEvent = 0
```
# Imports
Blink allows you to use multiple definition files through importing.  
Imports will pull all declarations (events, functions, scopes and types) from the target file and load them into the importing scope as a new scope using either the file name or a user provided name through the `as` keyword.  
```
import "../path/File.blink" --> Imports as a new scope "File"
type a = File.b
```
```
import "../path/File.blink" as Something --> Imports as a new scope "Something"
type a = Something.b
```
```
scope MyScope {
    --> Imports a new scope "Something" into "MyScope"
    import "../path/File.blink" as Something
}
type a = MyScope.Something.b
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
