# Navigation
[Home](https://github.com/1Axen/Blink/blob/main/README.md)  
[Installation](https://github.com/1Axen/Blink/blob/main/docs/Installation.md)  
[Getting Started](https://github.com/1Axen/Blink/blob/main/docs/Getting-Started.md)  
[Using Blink](https://github.com/1Axen/Blink/blob/main/docs/Using.md)
[Studio Plugin](https://github.com/1Axen/Blink/blob/main/docs/Plugin.md)
# Navigating
After installing the plugin locate it within your plugin tab in Studio.
> [!NOTE]
> After opening the plugin you will be prompted to give it access to inject scripts, the plugin needs this in order to generate the output files.  

<img src="../assets/plugin/Locate.png">

## Menu
> [!TIP]
> You can open the side menu using the sandwich button on the left hand side.
<img src="../assets/plugin/Menu.png">  

Within the menu you can manage your network description files.
<img src="../assets/plugin/Navigation.png">  

## Saving
To save a network description simply press the save button at the bottom of the side menu.   
This will prompt you to save whatever is currently in the editor.
> [!TIP]  
> You can save to already existing files by simply inputting their name

<img src="../assets/plugin/Save.png">  

## Generating
To generate your networking modules simply press the "Generate" button on your desired file.  
This will open a prompt asking you to select your desired output destination within the game explorer.  

<img src="../assets/plugin/Generate.png"> 

Once you've selected your desired output destination simply press "Generate" and your files will be ready.  

<img src="../assets/plugin/GenerateSelected.png"> 

If no issues arise Blink will generate the following Folder containing your networking modules:  

<img src="../assets/plugin/Output.png"> 

## Editor
> [!NOTE]
> The editor does not currently offer auto completion or error checking.
> This is planned to be fixed within the next release.

<img src="../assets/plugin/Editor.png">  
   
    
> [!TIP]
> Although it lacks proper error checking while writing it can still detect certain bad syntax, highlighting it in red.  
> <img src="../assets/plugin/Invalid.png">

## Errors
Upon generating output files, Blink will parse the source contents and inform you of any errors within your files that are blocking generation.  

> <img src="../assets/plugin/Error.png">