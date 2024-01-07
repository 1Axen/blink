# Navigation
[Home](https://github.com/1Axen/Blink/blob/main/README.md)  
[Installation](https://github.com/1Axen/Blink/blob/main/docs/Installation.md)  
[Getting Started](https://github.com/1Axen/Blink/blob/main/docs/Getting-Started.md)  
[Using Blink](https://github.com/1Axen/Blink/blob/main/docs/Using.md)
# Options
Options go at the top of a source file and are used to configure the output of Blink.
```
option [OPTION] = [VALUE]
```
## `ServerOutput` and `ClientOutput`
These options allow you to specify where Blink will generate files.
```
option ServerOutput = "../Network/Server.luau"
option ClientOutput = "../Network/Client.luau"
```
## `ManualReplication`
Default: `false`  
Controls wether Blink will replicate events and functions automatically at the end of every frame.  
When set to `true` automatic replication will be disabled and instead a `StepReplication` function will be exposed.
# Basic syntax and supported types
You can mark any type (`struct`, `enum`, `type`) as optional by appending `?` after it
## Primitives
You can define a primitive using the `type` keyword  
Supported primitives are `u8 u16 u32 i8 i16 i32 f32 f64 bool string vector buffer CFrame`  
Arrays can be defined by appending `[SIZE]` or `[[MIN]..[MAX]]` after the primitive type  
Primitives can be constrained to ranges by writing `([MIN]..[MAX])` after the primitive type. Ranges are inclusive.  
```
type Simple = u8
type Optional = u8?
type Array = u8[1]
type Range = u8[0..100]
```
## Enums
You can define enums using the `enum` keyword  
```
enum State = ( Starting, Started, Stopping, Stopped )
```
## Structs
You can define structs using the `struct` keyword  
Structs can also hold structs within.  
```
struct Entity = {
    Identifier = u8,
    Health = u8(0..100),
    State = ( Dead, Alive )?,
    Direction = vector(0..1),
    Substruct = {
        Empty = u8[0],
        Complex = u8[1..12],
        Vector = UnitVector,
    }?
}
```
## Maps
Coming soon!
## Instances
Coming whenever ROBLOX gives us access to instance ids.
## Events
You can define events using the `event` keyword  
Events have 3 fields which must be defined in the **correct order**: `From`, `Type`, `Data`  
`From` - `Client` or `Server`  
`Type` - `Reliable` or `Unreliable`  
`Call` - `SingleSync` or `ManySync` or `SingleAsync` or `ManyAsync`  
`Data` - Can hold either a type definition or a reference to an already defined type  
```
event Simple = {
    From = Client,
    Type = Unreliable,
    Call = SingleSync,
    Data = u8
}

event Reference = {
    From = Client,
    Type = Unreliable,
    Call = SingleSync,
    Data = Entity
}

event Complex = {
    From = Client,
    Type = Unreliable,
    Call = SingleSync,
    Data = {
        Field = u8
    }
}
```
# Limitations
## Referencing types
A type must be defined earlier in the source for it to be referenceable, you cannot reference a type before it has been defined.
```
struct Invalid = {
    Field = Number
}
type Number = u8
```
```
[ERROR]
    |
002 |     Field = Number
    |             ^^^^^^ Unknown type referenced.
```
## Events order
Event fields must be in the exact order specified in the Events section.
```
event Example = {
    Type = Reliable,
    From = Server,
    Call = SingleSync,
    Data = u8
}
```
```
[ERROR]
    |
002 |     Type = Reliable,
    |     ^^^^ Unexpected key: Type, expected: "From".
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
