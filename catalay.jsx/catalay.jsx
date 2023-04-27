// Polyfills -------------------------------------------------------------------
Array.prototype.indexOf = function (item) {
  for (var idx = 0; idx < this.length; idx++) {
    if (this[idx] === item) return idx;
  }
  return -1;
}

Array.prototype.includes = function (item) {
  return (this.indexOf(item) !== -1);
}

String.prototype.trim = function () {
    return this.replace(/(^[\s\n\r\t\x0B]+)|([\s\n\r\t\x0B]+$)/g, '');
}
//------------------------------------------------------------------------------
Document.prototype.getOrCreateLayer = function (name, color) {
  var layer = this.layers.itemByName(name);
  if (!layer.isValid) {
    layer = this.layers.add({layerColor: color, name: name});
  }
  return layer;
}

// Set page margins in mm
Page.prototype.setPageMargins = function(mm) {
  this.marginPreferences.properties = {
    left: mm,
    right: mm,
    top: mm,
    bottom: mm
  };
}
//------------------------------------------------------------------------------

const Presets = {
  image: {
    strokeWeight: 0,
    layerColor: UIColors.BRICK_RED,
  },
  text: {
    layerColor: UIColors.DARK_BLUE,
  }
}

main();

function main() {
  const jsonData = readJsonFile();
  // Check if the JSON data successfully read
  if (!jsonData) {
    alert("JSON file not found.");
  } else {
    // Create a new document with the correct page size
    const doc = app.documents.add({
      documentPreferences: {
        facingPages: false,
        pageWidth: 148,
        pageHeight: 210
      }
    });
    const layers = createLayers(doc);
    const numPages = jsonData.pages.length;
    // Get the page numbers to process and add
    const pagesToProcess = openRangeEditDialog("Enter pages to process:", "1-"+String(numPages));
    // Loop through each page in the JSON data
    var curPageIdx = -1;
    // create a dummy png file in a temporary directory
    const dummyPngFile = saveDummyPngToTmp();
    try {
    for (var inputPageIdx = 0; inputPageIdx < numPages; inputPageIdx++) {
      if (!pagesToProcess.includes(inputPageIdx)) continue;
      curPageIdx += 1;
      // Ensure we have enough pages in the document
      for (var pIdx = doc.pages.length-1; pIdx<curPageIdx; pIdx++) {
        // If a number of pages is less then required, add a new page
        doc.pages.add()
      }
      var page = doc.pages.item(curPageIdx);
      page.setPageMargins(3);
      var pageData = jsonData.pages[inputPageIdx];
      // Add the page title to the page
      addLabel(page, pageData.title, layers.text);
      // Loop through each group on the page
      var numGroups = pageData.groups.length;
      for (var gIdx = 0; gIdx < numGroups; gIdx++) {
        var groupData = pageData.groups[gIdx];
        // Add a new group title to the page
        addLabel(page, groupData.title, layers.text);
        // Loop through each item in the group
        var numItems = groupData.items.length;
        for (var iIdx = 0; iIdx < numItems; iIdx++) {
          var itemData = groupData.items[iIdx];
          // Add the item image to the page
          var img = addImage(page, itemData, layers.items, doc.links, dummyPngFile);
        }
        // Loop through each label in the group
        var numLabels = groupData.labels.length;
        for (var lIdx = 0; lIdx < numLabels; lIdx++) {
          var labelData = groupData.labels[lIdx];
          // Add the item label to the page
          var labelFrame = addLabel(page, labelData, layers.text);
        }
      }
    } } catch (err) {
      alert("Unhandled error during script execution:\n" + err);
    } finally{
    dummyPngFile.remove();}
  }
}

function readJsonFile() {
  var jsonFile = File.openDialog( ["Open the layout file", "JSON:*.json;All files:*.*", false] );

  if (jsonFile === null || !jsonFile.exists) {
    alert("JSON file not found.");
  } else {
    try {
      // Read the JSON file and parse the data
      jsonFile.open("r");
      var jsonString = jsonFile.read();
    } catch (err) {
      alert('Could not read input file "' + jsonFile.path +'".');
    } finally {
      jsonFile.close();
    }
    var jsonData = eval("(" + jsonString + ")");
    return jsonData;
  }
}

// Set page margins in mm
function setPageMargins(page, mm) {
  page.marginPreferences.properties = {
    left: mm,
    right: mm,
    top: mm,
    bottom: mm
  };
}

//--------------------- Range Dialog -------------------------------------------
function openRangeEditDialog(greet, defaultValue) {
  var myDialog = app.dialogs.add({name: greet});
  // Add dialog columns
  with (myDialog.dialogColumns.add()) {
    staticTexts.add({staticLabel: 'Pages to process ("1, 3-5, 7 11"):'});
    var myRangeEditBox = textEditboxes.add({editContents: defaultValue});
  }
  // Show dialog
  var result = myDialog.show();
  // Process result
  if (result == true) {
    var editedRanges = myRangeEditBox.editContents;
    myDialog.destroy();
    return parseNumberRanges(editedRanges);
  } else {
    myDialog.destroy();
    return parseNumberRanges(defaultValue);
  }
}

function sortUnique(numberArray) {
  if (numberArray.length === 0) {
    return numberArray;
  } else {
    const arr = numberArray.sort(function(a, b){return a - b});
    const result = [arr[0]];
    for (var i = 1; i < arr.length; i++) {
      if (arr[i - 1] !== arr[i]) {
        result.push(arr[i]);
      }
    }
    return result;
  }
}

function parseNumberRanges(inputString) {
  // Split input string by comma or whitespace
  const numbersArray = inputString.split(/[\s,]+/);
  const resultArray = [];
  // Loop through the numbersArray and extract individual numbers and ranges
  for (var i = 0; i < numbersArray.length; i++) {
    var number = numbersArray[i];
    // If number is a range, extract the start and end values and add them to the result array
    if (number.indexOf("-") > 0) {
      var rangeParts = number.split("-");
      if (rangeParts.length > 2 || isNaN(rangeParts[0]) || isNaN(rangeParts[1])) {
        alert("Range '" + number + "' is invalid!")
      } else {
        for (var j = parseInt(rangeParts[0]); j <= parseInt(rangeParts[1]); j++) {
          resultArray.push(j - 1);
        }
      }
    }
    // If number is a single value, add it to the result array
    else if (!isNaN(number)) {
      resultArray.push(parseInt(number) - 1);
    } else {
      alert("Number '" + number + "' is invalid!")
    }
  }
  return sortUnique(resultArray);
}
//------------------------------------------------------------------------------

function debug(obj){alert(obj.toSource());}

function createLayers(doc) {
  const items = doc.getOrCreateLayer("items", Presets.image.layerColor);
  const text = doc.getOrCreateLayer("labels", Presets.text.layerColor);
  return {items: items, text: text};
}

function boundsAreNone(a) {
  if (a.length !== 4) return false;
  for (var i = 0; i < a.length; ++i) {
    if (a[i] !== 0.0) return false;
  }
  return true;
}

// Add a group label to the given page with the given label data
function addLabel(page, labelData, layer) {
  if (!boundsAreNone(labelData.bounds)) { // Check if label is not None
    var text
    if (labelData.text) {text = labelData.text} else {text = ""}
    // Create a new text frame for the label
    var labelFrame = page.textFrames.add(layer, withProperties = {
      // Set the bounds of the label frame
      geometricBounds: labelData.bounds,
      // Set the contents and size of the label frame
      contents: text,
    });
    if (labelFrame.paragraphs && labelFrame.paragraphs.length > 0) {
      var paragraph = labelFrame.paragraphs.item(0);
      paragraph.pointSize = labelData.textSize;
      //Set the justification of the paragraph to center align.
      paragraph.justification = Justification.centerAlign;
    }
    // Return the created frame
    return labelFrame;
  } else {
    return null;
  }
}

// Add an image to the given page with the given image path and bounds
function addImage(page, itemData, layer, links, dummyPngFile) {
  // Create a new rectangle frame for the image
  var imageFrame = page.rectangles.add(layer, withProperties = {
      name: ("item_" + itemData.id),
      geometricBounds: itemData.bounds,
      strokeWeight: Presets.image.strokeWeight,
      contentType: ContentType.GRAPHIC_TYPE,
    });
  imageFrame.frameFittingOptions.fittingOnEmptyFrame = EmptyFrameFittingOptions.PROPORTIONALLY;
  const imgPath = itemData.imagePath.trim();
  // Check if the file exists
  const imageFile = new File(imgPath);
  if (imageFile.exists) {
    // Load the image into the image frame
    imageFrame.place(imageFile);
  } else {
    imageFrame.place(dummyPngFile);
    links.lastItem().reinitLink("file:"+imageFile);
    //imageFrame.insertLabel("path", imgPath);
  }
  return imageFrame;
}

function saveDummyPngToTmp() {
  const png = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1F\x15\xC4\x89\x00\x00\x00\x0A\x49\x44\x41\x54\x78\x9C\x63\x00\x01\x00\x00\x05\x00\x01\x0D\x0A\x2D\xB4\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";
  var tmpPath = $.getenv("TMPDIR") || $.getenv("TMP");
  if (!tmpPath) {
    throw new Error("Could not access the temporary directory!");
    bp();
  } else {
    const lastChar = tmpPath.charAt(tmpPath.length - 1);
    const tmpName = "_CatalayJSX_tmp_" + String($.hiresTimer) + ".png";
    if (lastChar === "/" || lastChar === "\\") {
      tmpPath = tmpPath + tmpName;
  } else {
    tmpPath = tmpPath + "/" + tmpName;
  }
  const pngFile = new File(tmpPath);
  try {
    pngFile.encoding = "BINARY";
    pngFile.open("w");
    pngFile.write(png);
  } catch (err) {
    throw new Error("Could not save a dummy PNG file for invalid link support!");
  } finally {
    pngFile.close();
  }
  return pngFile;
 }
}
