EEG Analyzer - A SPM MATLAB Toolbox
===================================
The "EEG Analyzer" toolbox for SPM provides a user-friendly interface for M/EEG visualization. It reads SPM M/EEG files and also offers basic M/EEG filtering options. If present, events are also shown.

Based on our previous work, this toolbox was developed as an alternative visualization tool for SPM "Graphics" in order to show selected signals without overlapping between them and even with different voltage scales. 
It can be used to display signals resulting from our co-developed SPM toolboxes:

1. [SpikeDet](http://beams.ulb.ac.be/research-projects/spm-eeg-spike-detection-toolbox) : a toolbox for detecting spikes in EEG.

2. [SGTT - Synaptic Gains Tracking Toolbox](http://beams.ulb.ac.be/research-projects/synaptic-gains-tracking-toolbox)

If you use this toolbox for your research involving a publication (in a journal, in a conference, etc.), please cite it by including as much information as possible from the following:

>*Rudy Ercek, EEG Analyzer: a SPM M/EEG Vizualization Toolbox, Université Libre de Bruxelles, https://bitbucket.org/ulbeeg/eeganalyzer, 2018*

Requirements
------------
1. [MATLAB (minimal version R2007b)](https://www.mathworks.com/)
2. [SPM12](http://www.fil.ion.ucl.ac.uk/spm/)

Installation
------------
1. Download [SPM12](http://www.fil.ion.ucl.ac.uk/spm/software/spm12/)
2. Decompress the downloaded "spm12.zip" file in a folder of your choice.
3. After running Matlab, add the SPM folder to Matlab search path: Menu “HOME” and button “Set Path” in the last Matlab versions. Another solution: go to the SPM folder and type the command “addpath(pwd)” each time you want to run SPM in Matlab.
4. Exit Matlab.
5. Download [EEGAnalyzer](https://bitbucket.org/ulbeeg/eeganalyzer/downloads/).
6. Decompress the files and its folder in the spm subfolder "toolbox".
7. Rename the decompressed folder to "EEGAnalyzer" (case sensitive). 
8. Check the files in the "EEGAnalyzer" subfolder. You should have at least the "EEGAnalyzer.m" file in this folder.

Run EEG Analyzer
----------------
After adding SPM directory in the matlab path, type the command "spm" in the MATLAB console. After choosing the M/EEG module, you can run EEGAnalyzer with the toolbox menu.

Future improvements
-------------------
Depending on the developers ‘schedule and EEG Analyzer’s use/success among people, several improvements are considered for future versions of EEG Analyzer, e.g. 

- Export the displayed main area as an image for publications.
- Change the channels order.
- Add, edit and remove events in the opened SPM file .
- Save the displayed (and filtered) channels as a new M/EEG SPM file (with events).

Acknowledgement
---------------
The developers of this SPM toolbox would like to thank the co-developers of SGTT and SpikeDet toolboxes, namely Xiaoya FAN and Antoine NONCLERCQ for their advices, remarks and testings during the development phase of EEG Analyzer.

They also want to thank the SPM team for developing the SPM MATLAB toolbox.

License
-------
EEG Analyzer is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; version 2 of the License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

See the [GNU General Public License](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html) for more details.

Contact : [Rudy Ercek](http://lisa.ulb.ac.be/image/index.php/Rudy_ERCEK) (rercek@ulb.ac.be)

Copyright © 2013-2018 - [Université Libre de Bruxelles](http://www.ulb.ac.be/) (ULB) 
