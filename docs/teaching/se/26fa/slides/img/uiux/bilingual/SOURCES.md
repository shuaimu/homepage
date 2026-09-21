# Bilingual contact sorting

## iPhone (PDF page 20)
- File: `iphone-english-chinese-2016.jpg`, 640 × 1136, unchanged full screenshot. Original pixelated redactions preserved.
- 觉主, 少数派, May 16, 2016: https://sspai.com/post/34222
- Published asset: https://cdnfile.sspai.com/attachment/origin/2016/05/15/327851.jpg?imageView2/2/w/1120/q/90/interlace/1/ignore-error/1
- English Contacts interface with Chinese names under hash headings. Historical screenshot, not a verified current-iOS result. Article also shows iPhone sorting correctly after phonetic fields are added.

## Android (PDF page 21)
- File: `android-phonetic-comparison.png`, 1830 × 1624, original developer comparison.
- Source: Ranmocy Sheng, MonkeyTree https://github.com/ranmocy/MonkeyTree
- Original asset: https://raw.githubusercontent.com/ranmocy/MonkeyTree/main/screenshots/screenshot_phone_5x_contact.png
- Typst crops the right screenshot at `(920,10,1820,1614)` and preserves status/navigation bars and original “After” annotation. No screenshot pixels are reconstructed.
- Result after MonkeyTree adds phonetic names and PINYIN type. Not evidence of an untouched Android default. Exact device, OS/app version, capture date, and complete language preferences are unknown.
- App listing: https://play.google.com/store/apps/details?id=me.ranmocy.monkeytree

## Technical background and limits
- Android Contacts name/sort API: https://developer.android.com/reference/android/provider/ContactsContract.ContactNameColumns#SORT_KEY_PRIMARY
- First-person Android 13 locale comparison: https://android.stackexchange.com/questions/251008/sort-contacts-by-hanyu-pinyin (March 31, 2023). ASUS worked with English; Google/Samsung worked after adding Simplified Chinese as secondary language.
- The screenshots use different contacts and different configurations. They illustrate a usability problem and a configured result, not a controlled platform comparison.
