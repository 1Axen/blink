# DeclareNet
A lightning fast, IDL-based networking solution for ROBLOX

# Installation
Download the source from GitHub  
Install Lune using Aftman in the repository directory  

# Generating code
Open a terminal in the `src` directory  
Run `lune Build [SOURCE_PATH] [OUTPUT_DIRECTORY_PATH]`  
You should now have a server and client module generated  

# Basic syntax and supported types
You can mark any type (`struct`, `enum`, `type`) as optional by appending `?` after it
## Primitives
You can define a primitive using the `type` keyword  
Supported primitives are `u8 u16 u32 i8 i16 i32 f32 f64 bool string vector`  
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
## Packets
You can define packets using the `packet` keyword  
Packets have 3 fields which must be defined in the **correct order**: `From`, `Type`, `Data`  
`From` - `Client` or `Server`  
`Type` - `Reliable` or `Unreliable`  
`Data` - Can hold either a type definition or a reference to an already defined type  
```
packet Simple = {
    From = Client,
    Type = Unreliable,
    Data = u8
}

packet Reference = {
    From = Client,
    Type = Unreliable,
    Data = Entity
}

packet Complex = {
    From = Client,
    Type = Unreliable,
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
## Packet order
Packet fields must be in the exact order specified in the Packets section.
```
packet Example = {
    Type = Reliable,
    From = Server,
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
# Credits
Credits to [Zap](https://zap.redblox.dev/) for the range and array syntax
