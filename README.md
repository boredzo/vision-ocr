# vision-ocr: A command-line tool for OCR using the Vision framework

This tool uses Apple's Vision framework—the same framework that powers text-selection in images in Safari and Preview—to enable recognizing text in images from the command line.

You give it an image and one or more named frames. A frame specifies a rectangular section of the image, relative to one of its corners. vision-ocr will recognize any text in each frame, then emit CSV output containing the text so recognized.

## Usage

> Usage: vision-ocr input-files [frames]
> 
> input-files is one or more paths to image files in common image formats such as PNG or JPEG.
> 
> frames are zero or more rectangles in the form “[name=]X,Y,WxH”. Units are in pixels unless specified (e.g., 2cm). Origin is upper-left for positive coordinates, lower-right for negative. If no frames specified, scan the entire image. If frames are named (e.g., pageNumber=-2cm,-2cm,2cmx2cm), output will be CSV.
> 
> Options:
> --transpose: Default is to emit one row per image. With --transpose, output will be one row per frame: name,value.
> --header: Default is to emit a header row before any data rows. With --no-header, header row will be omitted (this enables concatenating output from multiple runs).

## Specifying rectangles

The rectangle format for each frame is “X,Y,WxH”. X and Y are offsets relative to a corner, while W and H are the width and height of the rectangle.

Positive numbers are relative to the upper-left corner of the image, whereas negative numbers are relative to the lower-right. Any or all of the numbers can be negative; for example, “-0,-0,-2cmx-2cm” is a 2-cm square in the lower-right. You can mix and match; for example, “0,-1cm,1.5cmx-1cm” is a 1.5-by-1-cm rectangle positioned 1 cm above the lower-left corner (X and W relative to left, Y and H relative to bottom).

Note that specifying X, Y, W, or H in real-world measurements like in (inches) or cm (centimeters) only works on images with DPI information. Scanned images directly produced by scanner software (e.g., Image Capture) will generally have this. Photos taken on your phone or another camera will not.
