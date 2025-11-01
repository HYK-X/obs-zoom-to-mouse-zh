# OBS-Zoom-To-Mouse-zh

This project is the localized Chinese version of [BlankSourceCode/obs-zoom-to-mouse ](https://github.com/BlankSourceCode/obs-zoom-to-mouse)  During the development process, we referred to the relevant solutions from [ fixajteknik ](https://github.com/fixajteknik). It not only completes the Chinese localization of the project but also fixes the compatibility issues for the latest versions of OBS（32.0.2）, ensuring the normal functionality.

本项目是[BlankSourceCode/obs-zoom-to-mouse ](https://github.com/BlankSourceCode/obs-zoom-to-mouse)的汉化版本。在开发过程中，参考了[ fixajteknik ](https://github.com/fixajteknik)的相关方案，不仅完成了对该项目的中文本地化，还针对 OBS 高版本（32.0.2）进行了兼容性修复，确保功能可正常使用。

## Example
示例

![Usage Demo](obs-zoom-to-mouse-zh.gif)

## Install
安装

1.  Git clone the repo (or just save a copy of `obs-zoom-to-mouse.lua`)
    Git 克隆仓库（或者只是保存 `obs-zoom-to-mouse.lua` 的副本）
    
2.  Launch OBS
    启动 OBS
    
3.  In OBS, add a `Display Capture` source (if you don't have one already)
    在 OBS 中添加一个 `Display Capture` 源（如果您还没有的话）
    
4.  In OBS, open Tools -> Scripts
    在 OBS 中，打开工具 -> 脚本
    
5.  In the Scripts window, press the `+` button to add a new script
    在脚本窗口中，按 `+` 按钮添加新脚本
    
6.  Find and add the `obs-zoom-to-mouse.lua` script
    查找并添加 `obs-zoom-to-mouse.lua` 脚本
    
7.  For best results use the following settings on your `Display Capture` source
    为了获得最佳效果，请在您的 `Display Capture` 源上使用以下设置
    
    *   Transform:
        转换：
        *   Positional Alignment - `Top Left`
            位置对齐 - `Top Left`
        *   Bounding Box type - `Scale to inner bounds`
            边界框类型 - `Scale to inner bounds`
        *   Alignment in Bounding Box - `Top Left`
            边界框中的对齐 - `Top Left`
        *   Crop - All **zeros**
            裁剪 - 所有为零
    *   If you want to crop the display, add a new Filter -> `Crop/Pad`
        如果您想裁剪显示，请添加一个新的过滤器 -> `Crop/Pad`
        *   Relative - `False`
            相对 - `False`
        *   X - Amount to crop from left side
            X - 从左侧裁剪的量
        *   Y - Amount to crop form top side
            Y - 从顶部裁剪的量
        *   Width - Full width of display minus the value of X + amount to crop from right side
            宽度 - 显示器全宽减去 X 值加上从右侧裁剪的量
        *   Height - Full height of display minus the value of Y + amount to crop from bottom side
            高度 - 显示器全高减去 Y 值加上从底部裁剪的量
    
    **Note:** If you don't use this form of setup for your display source (E.g. you have bounding box set to `No bounds` or you have a `Crop` set on the transform), the script will attempt to **automatically change your settings** to zoom compatible ones. This may have undesired effects on your layout (or just not work at all).
    注意：如果您没有使用此设置形式来配置您的显示源（例如，您已将边界框设置为 `No bounds` ，或者您在转换中设置了 `Crop` ），脚本将尝试自动更改您的设置以使用兼容的缩放设置。这可能会对您的布局产生不良影响（或者根本不起作用）。
    
    **Note:** If you change your desktop display properties in Windows (such as moving a monitor, changing your primary display, updating the orientation of a display), you will need to re-add your display capture source in OBS for it to update the values that the script uses for its auto calculations. You will then need to reload the script.
    注意：如果您在 Windows 中更改了桌面显示属性（如移动显示器、更改主显示设备、更新显示器的方向），您需要重新添加您的显示捕获源到 OBS，以便更新脚本使用的自动计算值。然后您需要重新加载脚本。
    

## Usage
使用方法

1.  You can customize the following settings in the OBS Scripts window:
    您可以在 OBS 脚本窗口中自定义以下设置：
    
    *   **Zoom Source**: The display capture in the current scene to use for zooming
        缩放源：用于缩放的当前场景中的显示捕获
    *   **Zoom Factor**: How much to zoom in by
        缩放倍数：缩放的程度
    *   **Zoom Speed**: The speed of the zoom in/out animation
        缩放速度：缩放动画的快慢
    *   **Auto follow mouse**: True to track the cursor automatically while you are zoomed in, instead of waiting for the `Toggle follow` hotkey to be pressed first
        自动跟随鼠标：当您放大时，自动跟踪鼠标光标，而不是先按 `Toggle follow` 快捷键
    *   **Follow outside bounds**: True to track the cursor even when it is outside the bounds of the source
        超出边界跟随：当鼠标光标超出源边界时，仍然跟踪鼠标光标
    *   **Follow Speed**: The speed at which the zoomed area will follow the mouse when tracking
        跟随速度：跟踪时缩放区域跟随鼠标的速度
    *   **Follow Border**: The %distance from the edge of the source that will re-enable mouse tracking
        跟随边框：从源边缘到重新启用鼠标跟踪的距离
    *   **Lock Sensitivity**: How close the tracking needs to get before it locks into position and stops tracking until you enter the follow border
        锁定灵敏度：跟踪需要多接近位置才能锁定并停止跟踪，直到你进入跟随边框
    *   **Auto Lock on reverse direction**: Automatically stop tracking if you reverse the direction of the mouse.
        反向方向自动锁定：如果你反转鼠标方向，则自动停止跟踪。
    *   **Show all sources**: True to allow selecting any source as the Zoom Source - Note: You **MUST** set manual source position for non-display capture sources
        显示所有源：设置为 True 允许选择任何源作为缩放源 - 注意：你必须为非显示捕获源设置手动源位置
    *   **Set manual source position**: True to override the calculated x/y (topleft position), width/height (size), and scaleX/scaleY (canvas scale factor) for the selected source. This is essentially the area of the desktop that the selected zoom source represents. Usually the script can calculate this, but if you are using a non-display capture source, or if the script gets it wrong, you can manually set the values.
        设置手动源位置：将此选项设置为 True 可以覆盖计算出的 x/y（左上角位置）、宽度/高度（大小）和 scaleX/scaleY（画布缩放因子）以用于选定的源。这基本上是桌面区域，该区域由选定的缩放源表示。通常脚本可以计算这个值，但如果您使用的是非显示捕获源，或者脚本计算错误，您可以手动设置这些值。
    *   **X**: The coordinate of the left most pixel of the source
        X：源最左侧像素的坐标
    *   **Y**: The coordinate of the top most pixel of the source
        Y：源最顶部像素的坐标
    *   **Width**: The width of the source (in pixels)
        宽度：源宽度（以像素为单位）
    *   **Height**: The height of the source (in pixels)
        高度：源的高度（以像素为单位）
    *   **Scale X**: The x scale factor to apply to the mouse position if the source is not 1:1 pixel size (normally left as 1, but useful for cloned sources that have been scaled)
        X 缩放：如果源不是 1:1 像素大小，则应用于鼠标位置的 X 缩放因子（通常保留为 1，但对于已缩放的克隆源很有用）
    *   **Scale Y**: The y scale factor to apply to the mouse position if the source is not 1:1 pixel size (normally left as 1, but useful for cloned sources that have been scaled)
        Y 缩放：如果源不是 1:1 像素大小，则应用于鼠标位置的 Y 缩放因子（通常保留为 1，但对于已缩放的克隆源很有用）
    *   **Monitor Width**: The width of the monitor that is showing the source (in pixels)
        显示器宽度：显示源的显示器的宽度（以像素为单位）
    *   **Monitor Height**: The height of the monitor that is showing the source (in pixels)
        显示器高度：显示源的高度（以像素为单位）
    *   **More Info**: Show this text in the script log
        更多信息：在脚本日志中显示此文本
    *   **Enable debug logging**: Show additional debug information in the script log
        启用调试日志：在脚本日志中显示额外的调试信息
2.  In OBS, open File -> Settings -> Hotkeys
    在 OBS 中，打开文件 -> 设置 -> 快捷键
    
    *   Add a hotkey for `Toggle zoom to mouse` to zoom in and out
        添加一个快捷键 `Toggle zoom to mouse` 用于放大和缩小
    *   Add a hotkey for `Toggle follow mouse during zoom` to turn mouse tracking on and off (*Optional*)
        添加一个快捷键 `Toggle follow mouse during zoom` 用于开启和关闭鼠标跟踪（可选）

### Dual Machine Support
双机支持

1.  The script also has some **basic** dual machine setup support. By using my related project [obs-zoom-to-mouse-remote](https://github.com/BlankSourceCode/obs-zoom-to-mouse-remote) you will be able to track the mouse on your second machine
    该脚本还提供了一些基本的双机设置支持。通过使用我的相关项目 obs-zoom-to-mouse-remote，您将能够跟踪第二台机器上的鼠标
2.  When you have [ljsocket.lua](https://github.com/BlankSourceCode/obs-zoom-to-mouse-remote) in the same directory as `obs-zoom-to-mouse.lua`, the following settings will also be available:
    当 ljsocket.lua 与 `obs-zoom-to-mouse.lua` 位于同一目录下时，以下设置也将可用：
    *   **Enable remote mouse listener**: True to start a UDP socket server that will listen for mouse position messages from a remote client
        启用远程鼠标监听器：设置为 True 将启动一个 UDP 套接字服务器，该服务器将监听来自远程客户端的鼠标位置消息
    *   **Port**: The port number to use for the socket server
        端口号：用于套接字服务器的端口号
    *   **Poll Delay**: The time between updating the mouse position (in milliseconds)
        轮询延迟：更新鼠标位置的时间间隔（以毫秒为单位）
    *   For more information see [obs-zoom-to-mouse-remote](https://github.com/BlankSourceCode/obs-zoom-to-mouse-remote)
        更多信息请参阅 obs-zoom-to-mouse-remote

### More information on how mouse tracking works
关于鼠标跟踪如何工作的更多信息

When you press the `Toggle zoom` hotkey the script will use the current mouse position as the center of the zoom. The script will then animate the width/height values of a crop/pan filter so it appears to zoom into that location. If you have `Auto follow mouse` turned on, then the x/y values of the filter will also change to keep the mouse in view as it is animating the zoom. Once the animation is complete, the script gives you a "safe zone" to move your cursor in without it moving the "camera". The idea was that you'd want to zoom in somewhere and move your mouse around to highlight code or whatever, without the screen moving so it would be easier to read text in the video.
当你按下 `Toggle zoom` 快捷键时，脚本将使用当前鼠标位置作为缩放的中心。然后脚本将动画化裁剪/平移滤镜的宽度和高度值，使其看起来在该位置进行缩放。如果你开启了 `Auto follow mouse` ，那么滤镜的 x/y 值也会改变，以保持鼠标在动画缩放时可见。一旦动画完成，脚本会给你一个“安全区域”，你可以在这个区域内移动光标而不会移动“相机”。这个想法是，你想要在某个地方进行缩放，并移动鼠标来突出显示代码或任何内容，而屏幕不会移动，这样就可以更容易地阅读视频中的文本。

When you move your mouse to the edge of the zoom area, it will then start tracking the cursor and follow it around at the `Follow Speed`. It will continue to follow the cursor until you hold the mouse still for some amount of time determined by `Lock Sensitivity` at which point it will stop following and give you that safe zone again but now at the new center of the zoom.
当你将鼠标移动到缩放区域的边缘时，它将开始跟踪光标，并在 `Follow Speed` 处跟随它。它将继续跟随光标，直到你保持鼠标静止一段时间，这段时间由 `Lock Sensitivity` 决定。此时，它将停止跟随，并再次给你一个“安全区域”，但现在是在新的缩放中心。

How close you need to get to the edge of the zoom to trigger the 'start following mode' is determined by the `Follow Border` setting. This value is a pertentage of the area from the edge. If you set this to 0%, it means that you need to move the mouse to the very edge of the area to trigger mouse tracking. Something like 4% will give you a small border around the area. Setting it to full 50% causes it to begin following the mouse whenever it gets closer than 50% to an edge, which means it will follow the cursor *all the time* essentially removing the "safe zone".
您需要将鼠标移动到缩放边缘多近才能触发“开始跟随模式”由 `Follow Border` 设置决定。此值是边缘区域面积的百分比。如果您将其设置为 0%，则表示您需要将鼠标移动到区域的非常边缘才能触发鼠标跟踪。大约 4%将给区域周围提供一个小的边框。将其设置为满 50%会导致它开始跟随鼠标，只要鼠标距离边缘小于 50%，这意味着它将始终跟随光标，实际上消除了“安全区域”。

You can also modify this behavior with the `Auto Lock on reverse direction` setting, which attempts to make the follow work more like camera panning in a video game. When moving your mouse to the edge of the screen (how close determined by `Follow Border`) it will cause the camera to pan in that direction. Instead of continuing to track the mouse until you keep it still, with this setting it will also stop tracking immediately if you move your mouse back towards the center.
您还可以通过 `Auto Lock on reverse direction` 设置修改此行为，该设置试图使跟随工作更类似于视频游戏中的摄像机平移。当您将鼠标移动到屏幕边缘时（距离由 `Follow Border` 决定），它将使摄像机朝那个方向平移。与继续跟踪鼠标直到您将其保持静止不同，使用此设置，如果您将鼠标移回中心，它也会立即停止跟踪。

### More information on 'Show All Sources'
有关“显示所有源”的更多信息

If you enable the `Show all sources` option, you will be able to select any OBS source as the `Zoom Source`. This includes **any** non-display capture items such as cloned sources, browsers, or windows (or even things like audio input - which really won't work!).
如果您启用 `Show all sources` 选项，您将能够选择任何 OBS 源作为 `Zoom Source` 。这包括任何非显示捕获项，例如克隆源、浏览器或窗口（甚至像音频输入这样的东西——实际上可能无法工作！）。

Selecting a non-display capture zoom source means the script will **not be able to automatically calculate the position and size of the source**, so zooming and tracking the mouse position will be wrong!
选择非显示捕获缩放源意味着脚本将无法自动计算源的位置和大小，因此缩放和跟踪鼠标位置将会错误！

To fix this, you MUST manually enter the size and position of your selected zoom source by enabling the `Set manual source position` option and filling in the `X`, `Y`, `Width`, and `Height` values. These values are the pixel topleft position and pixel size of the source on your overall desktop. You may also need to set the `Scale X` and `Scale Y` values if you find that the mouse position is incorrectly offset when you zoom, which is due to the source being scaled differently than the monitor you are using.
为了解决这个问题，您必须通过启用 `Set manual source position` 选项并填写 `X` 、 `Y` 、 `Width` 和 `Height` 值来手动输入您选择的缩放源的大小和位置。这些值是源在您整个桌面上的像素左上角位置和像素大小。如果您发现缩放时鼠标位置不正确地偏移，这可能是因为源与您使用的监视器缩放不同，您可能还需要设置 `Scale X` 和 `Scale Y` 值。

Example 1 - A 500x300 window positioned at the center of a single 1000x900 monitor, would need the following values:
示例 1 - 一个位于单个 1000x900 监视器中心的 500x300 窗口，需要以下值：

*   X = 250 (center of monitor X 500 - half width of window 250)
    X = 250（显示器 X 中心 500 - 窗口宽度 250 的一半）
*   Y = 300 (center of monitor Y 450 - half height of window 150)
    Y = 300（显示器 Y 中心 450 - 窗口高度 150 的一半）
*   Width = 500 (window width)
    Width = 500（窗口宽度）
*   Height = 300 (window height)
    Height = 300（窗口高度）

Example 2 - A cloned display-capture source which is using the second 1920x1080 monitor of a two monitor side by side setup:
示例 2 - 一个克隆的显示捕获源，它使用的是双显示器并排设置的第二个 1920x1080 显示器：

*   X = 1921 (the left-most pixel position of the second monitor because it is immediately next to the other 1920 monitor)
    X = 1921（第二个显示器的最左侧像素位置，因为它紧挨着另一个 1920 像素的显示器）
*   Y = 0 (the top-most pixel position of the monitor)
    Y = 0（显示器的最顶部像素位置）
*   Width = 1920 (monitor width)
    Width = 1920（显示器宽度）
*   Height = 1080 (monitor height)
    高度 = 1080（显示器高度）

Example 3 - A cloned scene source which is showing a 1920x1080 monitor but the scene canvas size is scaled down to 1024x768 setup:
示例 3 - 一个复制的场景源，显示了一个 1920x1080 的显示器，但场景画布大小已缩放到 1024x768 的设置：

*   X = 0 (the left-most pixel position of the monitor)
    X = 0（显示器最左边的像素位置）
*   Y = 0 (the top-most pixel position of the monitor)
    Y = 0（显示器最顶部的像素位置）
*   Width = 1920 (monitor width)
    宽度 = 1920（显示器宽度）
*   Height = 1080 (monitor height)
    高度 = 1080（显示器高度）
*   Scale X = 0.53 (canvas width 1024 / monitor width 1920)
    X 缩放 = 0.53（画布宽度 1024 / 显示器宽度 1920）
*   Scale Y = 0.71 (canvas height 768 / monitor height 1080)
    Y 缩放 = 0.71（画布高度 768 / 显示器高度 1080）

I don't know of an easy way of getting these values automatically otherwise I would just have the script do it for you.
我不知道有简单的方法自动获取这些值，否则我就会让脚本为你完成这项工作。

Note: If you are also using a `transform crop` on the non-display capture source, you will need to manually convert it to a `Crop/Pad Filter` instead (the script has trouble trying to auto convert it for you for non-display sources).
注意：如果你也在非显示捕获源上使用 `transform crop` ，你需要手动将其转换为 `Crop/Pad Filter` （脚本在尝试自动为你转换非显示源时会有困难）。

## Known Limitations
已知限制

*   Only works on `Display Capture` sources (automatically)
    仅在 `Display Capture` 源上（自动）工作
    
    *   In theory it should be able to work on window captures too, if there was a way to get the mouse position relative to that specific window
        理论上，如果能够获取到相对于特定窗口的鼠标位置，它也应该能够在窗口截图中工作
    *   You can now enable the [`Show all sources`](#More-information-on-'Show-All-Sources') option to select a non-display capture source, but you MUST set manual source position values
        现在您可以通过启用 `Show all sources` 选项来选择非显示捕获源，但您必须设置手动源位置值
*   Using Linux:
    使用 Linux：
    
    *   You may need to install the [loopback package](https://obsproject.com/forum/threads/obs-no-display-screen-capture-option.156314/) to enable `XSHM` display capture sources. This source acts most like the ones used by Windows and Mac so the script can auto calculate sizes for you.
        您可能需要安装 loopback 包来启用 `XSHM` 显示捕获源。此源与 Windows 和 Mac 使用的源最相似，因此脚本可以为您自动计算大小。
    *   The script will also work with `Pipewire` sources, but you will need to enable `Allow any zoom source` and `Set manual source position` since the script cannot get the size by itself.
        脚本也可以与 `Pipewire` 源一起使用，但您需要启用 `Allow any zoom source` 和 `Set manual source position` ，因为脚本无法自行获取大小。
*   Using Mac:
    使用 Mac：
    
    *   When using `Set manual source position` you may need to set the `Monitor Height` value as it is used to invert the Y coordinate of the mouse position so that it matches the values of Windows and Linux that the script expects.
        当使用 `Set manual source position` 时，您可能需要设置 `Monitor Height` 的值，因为它用于反转鼠标位置的 Y 坐标，以便与脚本期望的 Windows 和 Linux 的值相匹配。
