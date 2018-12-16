# Change Log

## [2.1.1](https://github.com/gdombiak/OctoPod/tree/2.1) (2018-12-16)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/2.0...2.1)

**Fixed bugs:**

- Fix crash when file has no display text [\#156](https://github.com/gdombiak/OctoPod/issues/156)
- \[German\] Siri Command Responses do not replace variables [\#155](https://github.com/gdombiak/OctoPod/issues/155)

## [2.1](https://github.com/gdombiak/OctoPod/tree/2.1) (2018-12-09)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/2.0...2.1)

**Implemented enhancements:**

- Implement Siri shortcuts [\#147](https://github.com/gdombiak/OctoPod/issues/147)
- iOS widget [\#144](https://github.com/gdombiak/OctoPod/issues/144)
- Add upload date \(and maybe size\) to gcode files list [\#142](https://github.com/gdombiak/OctoPod/issues/142)
- System Menu [\#141](https://github.com/gdombiak/OctoPod/issues/141)
- Add new theme that follows OctoPrint's appearance color [\#140](https://github.com/gdombiak/OctoPod/issues/140)

**Fixed bugs:**

- Disable 'Refresh SD' button when app is locked [\#152](https://github.com/gdombiak/OctoPod/issues/152)
- Fix unusual bug where File has no display [\#150](https://github.com/gdombiak/OctoPod/issues/150)
- Camera rotation on Apple Watch.  [\#145](https://github.com/gdombiak/OctoPod/issues/145)

**Closed issues:**

- Disconnect cancels print [\#73](https://github.com/gdombiak/OctoPod/issues/73)

**Merged pull requests:**

- When using Siri, nil username/password is crashing [\#149](https://github.com/gdombiak/OctoPod/pull/149) ([chrisy](https://github.com/chrisy))
- Ask the user to authorize Siri [\#148](https://github.com/gdombiak/OctoPod/pull/148) ([chrisy](https://github.com/chrisy))

## [2.0](https://github.com/gdombiak/OctoPod/tree/2.0) (2018-11-11)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.12...2.0)

**Implemented enhancements:**

- Remember aspect ratio of first camera to improve user experience [\#138](https://github.com/gdombiak/OctoPod/issues/138)
- Allow to use FaceID for unlocking app [\#134](https://github.com/gdombiak/OctoPod/issues/134)
- Add local notification when print job is done [\#131](https://github.com/gdombiak/OctoPod/issues/131)
- Add new "Orange" theme [\#130](https://github.com/gdombiak/OctoPod/issues/130)
- Optimize camera screen size for new iPad Pro 11 inch [\#129](https://github.com/gdombiak/OctoPod/issues/129)
- Allow to set speed for extruding/retracting \(requires OctoPrint 1.3.10\) [\#127](https://github.com/gdombiak/OctoPod/issues/127)
- Allow to manually enter values besides using sliders in Move panel [\#126](https://github.com/gdombiak/OctoPod/issues/126)
- Improve move buttons layout to make it easier to use them [\#125](https://github.com/gdombiak/OctoPod/issues/125)
- OctoPrint 1.3.10 now requires websocket to be authenticated [\#121](https://github.com/gdombiak/OctoPod/issues/121)
- Allow to cancel objects via cancelobject plugin [\#93](https://github.com/gdombiak/OctoPod/issues/93)
- Add Apple Watch support [\#84](https://github.com/gdombiak/OctoPod/issues/84)

**Fixed bugs:**

- Camera image is sometimes not visible when coming back from full screen [\#137](https://github.com/gdombiak/OctoPod/issues/137)
- Fix crash when switching landscape/portrait mode  [\#124](https://github.com/gdombiak/OctoPod/issues/124)
- Changes to API key or URL of selected printer do not take immediate effect [\#123](https://github.com/gdombiak/OctoPod/issues/123)

## [1.12](https://github.com/gdombiak/OctoPod/tree/1.12) (2018-10-20)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.11...1.12)

**Implemented enhancements:**

- Let users disable zoom in/out of temp chart [\#120](https://github.com/gdombiak/OctoPod/issues/120)
- Adapt camera screen size according to aspect ratio [\#118](https://github.com/gdombiak/OctoPod/issues/118)
- Expose to user the reason why websocket is not refreshing [\#115](https://github.com/gdombiak/OctoPod/issues/115)
- Add Home button in Move window [\#112](https://github.com/gdombiak/OctoPod/issues/112)
- Allow to switch cameras while in full screen [\#99](https://github.com/gdombiak/OctoPod/issues/99)

**Fixed bugs:**

- Pull down text to refresh table is not translated [\#119](https://github.com/gdombiak/OctoPod/issues/119)
- Websocket fails to work with self-signed certs [\#114](https://github.com/gdombiak/OctoPod/issues/114)

**Closed issues:**

- Print job doesn’t show status [\#113](https://github.com/gdombiak/OctoPod/issues/113)

## [1.11](https://github.com/gdombiak/OctoPod/tree/1.11) (2018-10-15)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.10...1.11)

**Implemented enhancements:**

- Settings-\>Device - Hide login message when user is already logged into iCloud [\#111](https://github.com/gdombiak/OctoPod/issues/111)
- Show spinner when loading files since it could take some time [\#110](https://github.com/gdombiak/OctoPod/issues/110)
- Add support to auto-lock app while printing [\#109](https://github.com/gdombiak/OctoPod/issues/109)
- Improve websocket recovery logic [\#106](https://github.com/gdombiak/OctoPod/issues/106)
- Improve images resolution for retina display [\#104](https://github.com/gdombiak/OctoPod/issues/104)

**Fixed bugs:**

- Fix crash when subpanel height constraints where not calculated [\#107](https://github.com/gdombiak/OctoPod/issues/107)
- Websocket heartbeat causes OctoPrint warning [\#105](https://github.com/gdombiak/OctoPod/issues/105)
- Fix crash when camera finished loading image and there were no errors [\#103](https://github.com/gdombiak/OctoPod/issues/103)
- Cancelling the print should clean up progress information [\#102](https://github.com/gdombiak/OctoPod/issues/102)
- Fix crash when canceling, pausing, resuming job [\#101](https://github.com/gdombiak/OctoPod/issues/101)
- 'Not refreshing' alert stays on after connection was re-established [\#100](https://github.com/gdombiak/OctoPod/issues/100)

## [1.10](https://github.com/gdombiak/OctoPod/tree/1.10) (2018-10-08)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.9...1.10)

**Implemented enhancements:**

- Test app in iPhone SE due to its smaller screen [\#95](https://github.com/gdombiak/OctoPod/issues/95)
- Add Norwegian translation [\#91](https://github.com/gdombiak/OctoPod/issues/91)
- Add Italian translation [\#89](https://github.com/gdombiak/OctoPod/issues/89)
- Add Czech translation [\#88](https://github.com/gdombiak/OctoPod/issues/88)
- Add German translation [\#87](https://github.com/gdombiak/OctoPod/issues/87)
- Add Spanish translation [\#86](https://github.com/gdombiak/OctoPod/issues/86)
- Add support for multi-languages [\#17](https://github.com/gdombiak/OctoPod/issues/17)

**Fixed bugs:**

- Fix app crash when updating printer from non-main thread [\#98](https://github.com/gdombiak/OctoPod/issues/98)
- Fix crash when printing a file with invalid path [\#97](https://github.com/gdombiak/OctoPod/issues/97)
- Print done is not always marked as 100% done [\#94](https://github.com/gdombiak/OctoPod/issues/94)
- Domain Name with '-' Not accepted [\#92](https://github.com/gdombiak/OctoPod/issues/92)

**Closed issues:**

- Add Setting to choose language of the app [\#96](https://github.com/gdombiak/OctoPod/issues/96)

**Merged pull requests:**

- Add spanish translation from Spain [\#90](https://github.com/gdombiak/OctoPod/pull/90) ([ArtCC](https://github.com/ArtCC))

## [1.9](https://github.com/gdombiak/OctoPod/tree/1.9) (2018-09-26)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.8...1.9)

**Fixed bugs:**

- Crash when switching printer [\#85](https://github.com/gdombiak/OctoPod/issues/85)

## [1.8](https://github.com/gdombiak/OctoPod/tree/1.8) (2018-09-24)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.7...1.8)

**Implemented enhancements:**

- Add links to explain what Custom Controls are [\#82](https://github.com/gdombiak/OctoPod/issues/82)
- Add support for Tasmota plugin [\#81](https://github.com/gdombiak/OctoPod/issues/81)
- Add support for Domoticz switches [\#77](https://github.com/gdombiak/OctoPod/issues/77)
- Add support for Wemo switches [\#76](https://github.com/gdombiak/OctoPod/issues/76)
- Optimize screen size for new iPhones [\#75](https://github.com/gdombiak/OctoPod/issues/75)
- Allow to enable/disable confirmation dialogs on connect/disconnect [\#57](https://github.com/gdombiak/OctoPod/issues/57)
- Use iCloud sync to keep list of printers in synch between devices [\#51](https://github.com/gdombiak/OctoPod/issues/51)

**Fixed bugs:**

- Camera error message truncates text [\#80](https://github.com/gdombiak/OctoPod/issues/80)
- Fix crash when entered desired temp is not a number [\#74](https://github.com/gdombiak/OctoPod/issues/74)

**Closed issues:**

- Update to Swift 4.2 [\#79](https://github.com/gdombiak/OctoPod/issues/79)
- Update pod Charts to 3.2.0 [\#78](https://github.com/gdombiak/OctoPod/issues/78)

## [1.7](https://github.com/gdombiak/OctoPod/tree/1.7) (2018-09-10)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.6...1.7)

**Implemented enhancements:**

- Add page with links for support [\#72](https://github.com/gdombiak/OctoPod/issues/72)
- Improve text to indicate that user creds are only for HTTP Authentication [\#71](https://github.com/gdombiak/OctoPod/issues/71)
- Preserve device orientation when coming back from camera full screen [\#70](https://github.com/gdombiak/OctoPod/issues/70)
- Allow to set up the feed rate [\#65](https://github.com/gdombiak/OctoPod/issues/65)
- Support "app lock" mode [\#60](https://github.com/gdombiak/OctoPod/issues/60)

**Fixed bugs:**

- Fix crash when camera URL has invalid characters or is empty [\#69](https://github.com/gdombiak/OctoPod/issues/69)
- Fix error when displaying connection errors [\#68](https://github.com/gdombiak/OctoPod/issues/68)
- Multiple cameras hosted by OctoPrint not working [\#67](https://github.com/gdombiak/OctoPod/issues/67)
- Incorect webcam aspect ratio [\#66](https://github.com/gdombiak/OctoPod/issues/66)

**Closed issues:**

- Add basic auth support [\#64](https://github.com/gdombiak/OctoPod/issues/64)
- Multicam [\#55](https://github.com/gdombiak/OctoPod/issues/55)

## [1.6](https://github.com/gdombiak/OctoPod/tree/1.6) (2018-08-28)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.5...1.6)

**Implemented enhancements:**

- Accept IPv6 addresses and stop spell checker when adding printers [\#63](https://github.com/gdombiak/OctoPod/issues/63)
- Display error information when camera fails to render [\#62](https://github.com/gdombiak/OctoPod/issues/62)
- Allow to sort files by last successful print timestamp [\#54](https://github.com/gdombiak/OctoPod/issues/54)
- Allow to reprint completed job [\#53](https://github.com/gdombiak/OctoPod/issues/53)
- Allow to execute Custom Controls [\#15](https://github.com/gdombiak/OctoPod/issues/15)

**Fixed bugs:**

- Camera path may be incorrect when not using OctoPi [\#61](https://github.com/gdombiak/OctoPod/issues/61)

**Closed issues:**

- Add Cancel/Reset/Resume buttons. [\#56](https://github.com/gdombiak/OctoPod/issues/56)

## [1.5](https://github.com/gdombiak/OctoPod/tree/1.5) (2018-08-19)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.4...1.5)

**Implemented enhancements:**

- Add visual indication which printer is active in list of printers [\#50](https://github.com/gdombiak/OctoPod/issues/50)
- Support TPLink Smartplug to power printer on/off [\#49](https://github.com/gdombiak/OctoPod/issues/49)
- Add graph that shows temp history [\#48](https://github.com/gdombiak/OctoPod/issues/48)
- Add support for multiple cameras [\#47](https://github.com/gdombiak/OctoPod/issues/47)
- Make it explicit that webcam image supports full screen and zoom in/out [\#46](https://github.com/gdombiak/OctoPod/issues/46)
- Feature request: PSU Control plugin support. [\#36](https://github.com/gdombiak/OctoPod/issues/36)

**Fixed bugs:**

- Webcam full screen has white borders on iPhone X [\#52](https://github.com/gdombiak/OctoPod/issues/52)

**Closed issues:**

- Not very clear that wrench icons indicate that temps can be set [\#18](https://github.com/gdombiak/OctoPod/issues/18)

## [1.4](https://github.com/gdombiak/OctoPod/tree/1.4) (2018-08-05)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.3...1.4)

**Implemented enhancements:**

- Rename 'Print' to 'Job' in Job information dialog [\#45](https://github.com/gdombiak/OctoPod/issues/45)
- Display 'unknown' when remaining time is negative [\#44](https://github.com/gdombiak/OctoPod/issues/44)
- Increase terminal buffer size [\#43](https://github.com/gdombiak/OctoPod/issues/43)
- Allow to zoom in the webcam image [\#42](https://github.com/gdombiak/OctoPod/issues/42)
- Allow to navigate to OctoPrint's admin console [\#41](https://github.com/gdombiak/OctoPod/issues/41)
- Ask in a non-intrusive way to rate the app [\#25](https://github.com/gdombiak/OctoPod/issues/25)
- Allow to upload files from iCloud [\#2](https://github.com/gdombiak/OctoPod/issues/2)

## [1.3](https://github.com/gdombiak/OctoPod/tree/1.3) (2018-07-29)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.2...1.3)

**Implemented enhancements:**

- Recreate websocket when traffic is not working fine [\#40](https://github.com/gdombiak/OctoPod/issues/40)
- Disable 'Refresh SD' button if printer does not support SD [\#39](https://github.com/gdombiak/OctoPod/issues/39)
- Interrupted print when connecting [\#35](https://github.com/gdombiak/OctoPod/issues/35)
- Follow X, Y and Z axis invert settings from OctoPrint [\#34](https://github.com/gdombiak/OctoPod/issues/34)
- Ability to rotate or flip camera via settings [\#33](https://github.com/gdombiak/OctoPod/issues/33)

**Fixed bugs:**

- Fatal error: Can't remove more items from a collection than it has [\#38](https://github.com/gdombiak/OctoPod/issues/38)
- Print not starting from iPhone X IOS 12 beta 3 [\#37](https://github.com/gdombiak/OctoPod/issues/37)

## [1.2](https://github.com/gdombiak/OctoPod/tree/1.2) (2018-07-26)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.1...1.2)

**Implemented enhancements:**

- Improve text of buttons in job information window [\#31](https://github.com/gdombiak/OctoPod/issues/31)
- Add confirmation before canceling a print job [\#30](https://github.com/gdombiak/OctoPod/issues/30)
- Add themes so users can customize the app [\#26](https://github.com/gdombiak/OctoPod/issues/26)
- Add option to restart print [\#24](https://github.com/gdombiak/OctoPod/issues/24)
- Add option to sort files by date \(newest at the top\) [\#23](https://github.com/gdombiak/OctoPod/issues/23)
- Show complete tree of files [\#22](https://github.com/gdombiak/OctoPod/issues/22)
- Allow to watch printer in move tab [\#21](https://github.com/gdombiak/OctoPod/issues/21)
- Allow to disable motors [\#20](https://github.com/gdombiak/OctoPod/issues/20)
- Add terminal view to be able to track what printer is doing [\#16](https://github.com/gdombiak/OctoPod/issues/16)
- Allow to control flow rate of extruder [\#14](https://github.com/gdombiak/OctoPod/issues/14)
- Allow to control fan speed \(on/off\) [\#13](https://github.com/gdombiak/OctoPod/issues/13)
- Add confirmation dialog before disconnecting  [\#11](https://github.com/gdombiak/OctoPod/issues/11)

**Fixed bugs:**

- Progress bar shows incorrect progress [\#28](https://github.com/gdombiak/OctoPod/issues/28)
- Popovers are now displaying fine on iPhone Plus in landscape mode [\#27](https://github.com/gdombiak/OctoPod/issues/27)
- Fix crash when presenting dialog of failed connection [\#19](https://github.com/gdombiak/OctoPod/issues/19)

**Closed issues:**

- Fix Pod warning since no platform was specified as target [\#29](https://github.com/gdombiak/OctoPod/issues/29)

**Merged pull requests:**

- Adding a link in the README.md file to a wiki page with build and dep… [\#32](https://github.com/gdombiak/OctoPod/pull/32) ([bdelia](https://github.com/bdelia))

## [1.1](https://github.com/gdombiak/OctoPod/tree/1.1) (2018-07-18)
[Full Changelog](https://github.com/gdombiak/OctoPod/compare/1.0...1.1)

**Implemented enhancements:**

- Show visual indication when input text has invalid URL [\#9](https://github.com/gdombiak/OctoPod/issues/9)
- Add support for sending g-code commands [\#3](https://github.com/gdombiak/OctoPod/issues/3)
- Add support for refreshing files from SD card [\#1](https://github.com/gdombiak/OctoPod/issues/1)

**Fixed bugs:**

- Job information dialog shows "Unknown" origin when there is no job [\#4](https://github.com/gdombiak/OctoPod/issues/4)

**Closed issues:**

- Update Starscream dependency to 3.0.5 [\#10](https://github.com/gdombiak/OctoPod/issues/10)
- ios 10 support [\#8](https://github.com/gdombiak/OctoPod/issues/8)
- Rename Label "HOTEND" to "EXTRUDER" [\#7](https://github.com/gdombiak/OctoPod/issues/7)
- Increment version to 1.1 before release [\#6](https://github.com/gdombiak/OctoPod/issues/6)
- Add support for iOS 10.2 [\#5](https://github.com/gdombiak/OctoPod/issues/5)

## [1.0](https://github.com/gdombiak/OctoPod/tree/1.0) (2018-07-15)


\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*
