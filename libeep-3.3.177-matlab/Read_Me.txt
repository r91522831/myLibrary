  ========================================
  Februari 2017
  MATLAB / plugin for ANT continuous data, trigger files and averages
  Version 3.3.177
  ========================================

  This update adds support for .seg files.

  ========================================
  Februari 2017
  MATLAB / plugin for ANT continuous data, trigger files and averages
  Version 3.3.176
  ========================================

  Starting from version 3.3.176, libeep supports .evt data out of the box. As a
  result, the MATLAB importer now has the functions eepv4_read and
  eepv4_read_info to read cnt data. The old read_eep_cnt function is deprecated,
  but kept for compatibility.

  When eepv4_read(_info) is used, the function checks for an accompanying
  .evt file. If found, the contents are loaded. If not, it will try the same
  for an accompanying .trg file. If that also fails, the embedded triggers in
  the .cnt are tried.
