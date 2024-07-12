<div align="center">
  <img src="./docs/assets/Logo.png" class="center">
</div>
<h1>Blink</h1>
An IDL compiler written in Luau for ROBLOX buffer networking

# Performance
Blink aims to generate the most performant and bandwidth-efficient code for your specific experience, but what does this mean?  

It means lower bandwidth usage directly resulting in **lower ping\*** experienced by players and secondly, it means **lower CPU usage** compared to more generalized networking solutions.

*\* In comparison to standard ROBLOX networking, this may not always be the case but should never result in increased ping times.*

Benchmarks are available [here](https://1axen.github.io/blink/Benchmarks).

# Security
Blink does two things to combat bad actors:
1. Data sent by clients will be **validated** on the receiving side before  reaching any critical game code.
2. As a result of the compression done by Blink it becomes **harder** to snoop on your game's network traffic. .

# Get Started
Head over to the [installation](https://1axen.github.io/blink/Installation) page to get started with Blink.

# Credits
Credits to [Zap](https://zap.redblox.dev/) for the range and array syntax  
Credits to [ArvidSilverlock](https://github.com/ArvidSilverlock) for the float16 implementation  
Studio plugin auto completion icons are sourced from [Microsoft](https://github.com/microsoft/vscode-icons) and are under the [CC BY 4.0](https://github.com/microsoft/vscode-icons/blob/main/LICENSE) license.  
<a href="https://www.flaticon.com/free-icons/speed" title="speed icons">Speed icons created by alkhalifi design - Flaticon</a>
