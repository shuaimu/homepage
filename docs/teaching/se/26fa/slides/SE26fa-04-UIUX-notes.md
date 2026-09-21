# CSE 416 UI/UX teaching notes

September 21, 2026. The lecture has 21 slides, one per PDF page, ending with bilingual contact sorting. The 13 numbered teaching cues below group paired slides as one example. All screenshots are embedded for offline presentation. Example pages 3–21 show titles and images, using full phone screens where the source provides them. Tasks, version labels, questions, and citations remain in these notes.

## Teaching approach

Start with the examples and invite students to notice problems, choices, and tradeoffs. Avoid announcing a rule before an example or asking for the “correct” rule name. For each comparison, establish the user’s task, discuss the before slide, advance to the after slide, and ask what changed and how to test it. A newer design is not automatically better.



## Presentation controls

The paired examples have separate slides with titles and images. Uber Eats has one documented screenshot; its earlier flow is described aloud because a usable historical image could not be retrieved. Apple uses two slides: three beta 1 images side by side, followed by the later transparency slider. Advance with the viewer’s next-page click, Right Arrow, or presentation remote. Introduce each task and identify the release or state aloud using these notes. Sources remain in these notes and the asset provenance files. Text that belongs to the original screenshot is preserved.

| Example | Before page | After page | Suggested time |
| --- | --- | --- | --- |
| Apple Liquid Glass | 3 (three beta 1 images) | 4 (slider) | 6–10 min |
| Accessibility Reader | 5 | 6 | 10–15 min |
| Google Maps | 7 | 8 | 15–19 min |
| Android notifications | 9 | 10 | 19–24 min |
| Discord navigation reversal | 11 | 12 | 24–28 min |
| Chrome warning | 13 | 14 | 28–33 min |
| Instagram navigation | 15 | 16 | 33–40 min |
| Uber Eats confirmation | Earlier state described aloud | 17 | 40–45 min |
| Resistive seatback screen and capacitive iPhone | 18 (side by side) | — | 45–49 min |
| Capacitive cooktop controls | 19 (discussion image) | — | 49–52 min |
| Bilingual contact sorting | 20 (iPhone) | 21 (Android after phonetic setup) | 52–57 min |

## Opening, 0–6 minutes

**1. UI/UX: learning from examples.** Tell students they will inspect real interfaces, propose changes, and test their reasoning. Product screenshots illustrate documented versions and states, not necessarily today’s exact interface.


**2. Learning through examples.** Tell students: “We’ll learn through examples and apply our common sense.” Invite them to explain what seems clear or confusing in each interface. Different experiences may lead to different judgments; ask what observations could test those judgments.

## Example discussions, 6–52 minutes

**3. Apple Liquid Glass.** Use two slides within four minutes. Start with the actual complaints before discussing a remedy.

- **Page 3, left image: notifications (about 40 seconds):** Beto Moedano’s June 9, 2025 post shows white notification text against pale blue/green wallpaper. Ask students to read “Sign up for labs.” The full 738 × 1600 original screenshot preserves the entire notification screen. Say the individual reaction aloud, “I can’t see anything,” without presenting it as a measured usability result. [Original post](https://twitter.com/betomoedano/status/1932189570604437886).
- **Page 3, center image: cluttered controls (about 35 seconds):** Holly’s June 10 post shows Home Screen icons beneath playback and utility controls. Ask which shapes are actionable. The slide shows the complete phone from the larger original image. [Original post](https://twitter.com/AnxiousHolly/status/1932330130967257360). Both social posts are contemporaneous with the first iOS 26 developer beta, but do not display a build number.
- **Page 3, right image: beta 1 controls (about 90 seconds):** Jay Peters’ screenshot documents iOS 26 developer beta 1. Ask students to locate the flashlight and screen-recording controls and distinguish the controls from the Home Screen behind them. This is a different device from the other two captures. [The Verge, June 23, 2025](https://www.theverge.com/news/691540/apple-ios-26-liquid-glass-control-center-fixed-beta).
- **Page 4, later user choice (about 75 seconds):** Apple’s WWDC26 Podcasts demonstration shows its iOS 27 transparency slider toward the tinted end. Ask what the default should be, who needs another setting, and whether users will find it. The image demonstrates a later control in a different app, not the same notification or Control Center task. [Apple’s WWDC26 session, 23:08](https://developer.apple.com/videos/play/wwdc2026/102/).

**Chronology:** Liquid Glass first appeared with iOS 26 in June 2025. Apple added binary Clear/Tinted options in iOS 26.1, then presented a continuous slider with iOS 27 at WWDC26. The slider is later than the original launch complaints, but was not a post-beta-1 fix for iOS 27. [Apple’s iOS 26 update history](https://support.apple.com/en-gb/123075) documents Clear/Tinted. These examples raise readability and user-control questions. Test across different wallpapers and users before claiming that a change solves the problem.

**4. Apple Accessibility Reader.** Use Apple’s official May 13, 2025 iPhone comparison: the opening of The Odyssey in a dense original document, then in Accessibility Reader. The 1960 × 1400 press image supplies both full phone screens. This is a reading-mode comparison, not an older OS versus a newer OS. The screenshots show different amounts of the same text as it reflows. Larger type, spacing, and spoken-content controls make the change visible. Different users need different settings. Ask what semantics and reading order must survive reflow and spoken output. [Apple’s announcement](https://www.apple.com/newsroom/2025/05/apple-unveils-powerful-accessibility-features-coming-later-this-year/).

**5. Google Maps incident reporting.** The before is frame 74 of Google’s October 2019 iOS demo. The after is the 7-second frame from Google’s July 2024 Android demo. Compare the compact three-column icon layout with two-column tiles. Both full phone screens are shown, including all visible incident categories. Platforms, category labels, and content differ. Do not infer a precise tap-area increase or WCAG conformance from screenshots. The underlying hit areas are not measured. Connect to Fitts’s law qualitatively and propose a stationary test of selection errors.

**6. Android delivery notifications.** Both views come from Google’s Jetsnack codelab, a sample application with a simulated checkout. The before image is a frame from its standard-notification animation; the after is the codelab’s ProgressStyle image. Both depict the same order stage, “on its way.” The after adds a progress tracker and an estimated time in the header. The codelab then explains promotion to Live Updates. This is an implementation migration, not evidence of a commercial delivery app redesign or measured user benefit. Ask about stale tracking and whether the progress bar’s meaning is clear.

**7. Discord navigation reversal (PDF pages 11–12).** Task: you are browsing a server and receive a direct message. Where would you look? December 2023 put Servers and Messages in separate bottom tabs. In May 2024, Discord reunited them in Home, placing a DM entry above servers. Discord explicitly linked the revision to feedback about switching between desktop and mobile. Ask whether a dedicated Messages tab is easier to discover, and how familiar locations affect experienced users. Neither layout wins for every task. The images use different themes and slightly different content; focus on navigation, not color. Both are full-screen official previews.

Sources: [December 2023 redesign](https://discord.com/blog/improving-our-mobile-experience) and [May 2024 revision](https://discord.com/blog/refining-discords-mobile-experience-with-your-feedback). Proposed test: ask a desktop user and a new user to move between a server and a DM, recording wrong turns.

**8. Chrome suspicious-notification warning.** Google’s May 8, 2025 announcement shows both a flagged notification and its revealed content. The teaching comparison displays the deceptive content first, then reveals Chrome’s protective warning. These are two views of the same feature, not a chronology of releases or the order of the actual interaction: in the product, the warning appears first, and “Show notification” reveals the content. Chrome uses on-device detection to flag suspected spam and offers Unsubscribe or Show notification. The error-prevention discussion concerns an impulsive click on a deceptive virus message. The warning adds friction and context; it does not guarantee prevention. Ask how false positives should be handled without training users to ignore warnings.

**9. Instagram navigation (PDF pages 15–16).** Task: open DMs, find Reels, and create a post. Before: DMs at the top right, Create in the bottom center, Reels fourth. After: Reels second, DMs centered in the bottom bar, Create top left. Discuss thumb reach, learned locations, and the tradeoff between consuming, messaging, and creating. The before is frame 0 of principal designer Gabe Alves’s opt-in demonstration, published in his 2025 project case study. Its large banner previews the upcoming navigation; the actual current navigation is at the bottom edge. The after is the Home phone from Meta’s September 2025 release artwork. These are first-party design/release illustrations with different feeds, not captures of one user’s live account. The case-study video file was exported in January 2026, so it is not a dated 2025 customer recording.

Sources: [Gabe Alves, Nav Re-think](https://thinkgabrielalves.com/portfolio/instagram-new-nav/) and [Meta’s September 2025 announcement](https://about.fb.com/news/2025/09/in-india-instagram-debuts-a-reels-first-experience-for-its-mobile-app/). Distinguish the global navigation change from the separate Reels-first landing-page test in India. The selected after screen still opens on Home. Proposed test: give experienced users the three tasks without coaching and observe wrong taps.

**10. Uber Eats order confirmation (PDF page 17).** The matching interface is the consumer food-order flow. Introduce the task: “You just tapped Place order, but notice that the delivery address might be wrong.” Describe the earlier state before showing the screenshot: a progress indicator beside “Placing order…” and a single Undo button. Then show the September 2023 capture with Confirm (00:06), a progress fill in the button, and Undo. A customer who has checked the details can confirm immediately; doing nothing lets the order proceed. Ask students which action to take for the wrong address and what happens if they do nothing.

The earlier flow is documented by a December 19, 2020 recording reproduced in a [January 2023 filing, pp. 8–9](https://www.registredesactionscollectives.quebec/en/Fichier/Document?NomFichier=11549.pdf). Paragraph 17(f) describes a few seconds to review/cancel before the order goes to the restaurant. Use only the screenshot/interaction description, not the unrelated legal allegations. This demonstrates that the recovery window already existed. Do not claim the old flow sent orders immediately or lacked Undo. A usable image could not be retrieved from that PDF for embedding, so the historical comparison is verbal.

[Robert Meza’s September 21, 2023 original post](https://www.linkedin.com/posts/robertcmeza_would-this-be-yet-another-dark-pattern-activity-7110675422853390336-JkHH) supplies the full phone screenshot. Its red circle and black redactions belong to the author. Meza reports a seven-second timer and automatic continuation; the actual screenshot has six seconds remaining. [José Viegas’s July 28, 2023 observational walkthrough](https://medium.com/@josepedroviegas/challenge-2-wireframing-uber-eats-app-bda249e21eed) describes a 15-second review window. His article also contains student wireframes, which are not used as product screenshots. These accounts do not establish when the Confirm shortcut rolled out or the default across current devices/markets. The instructor recalls 15 seconds in their current experience; distinguish that observation from the dated slide capture.

Discuss the design as a tradeoff, not a proven improvement: the shortcut can avoid waiting, the visible timer exposes progress, and Undo permits recovery. Conversely, a countdown may rush a reader, and “Confirm” can imply that a second tap is required even though the order proceeds automatically. Proposed test: can participants explain what happens if they wait and successfully undo a wrong address? Discuss feedback, easy reversal, and user control.

**11. Resistive touch vs capacitive touch (PDF page 18).** Left: an older Delta 737-800 seatback entertainment screen from The Points Guy’s 2017 Boston–Los Angeles review. Right: Apple’s original iPhone finger-typing illustration from its 2007 user guide. Ask students how pressing a seatback screen feels different from tapping their phone, and how repeated presses might affect the passenger in front. Discuss required pressure, feedback after a touch, reach, calibration, and expectations formed by phones. These are different products and tasks, not a before/after redesign or a measured comparison.

The [original flight review](https://thepointsguy.com/airline/reviews/delta-basic-economy-flight-review/) identifies the aircraft and older touch-operated system. It reports no responsiveness problems on that flight, so this photograph is not evidence of a malfunction. The [DMC manufacturer explanation](https://www.dush.co.jp/english/museum/touchscreens/around/In-flight.asp) documents resistive touch in older in-flight entertainment generally. A [2018 Delta passenger discussion](https://www.flyertalk.com/forum/delta-air-lines-skymiles/1939892-how-often-does-delta-repair-older-ife-screens.html) identifies the older light-bezel screen style as resistive, but that is an informal report rather than a manufacturer specification. The pictured unit’s exact touch hardware has not been independently confirmed. Use the photo as an illustration of the older seatback-screen interaction, and make that limitation explicit when teaching the technical distinction. Do not generalize to all Delta, United, or American screens; newer systems can be capacitive.

Resistive touch detects pressure that brings layers into contact; it can accept a finger or passive stylus. Capacitive sensing detects changes in capacitance without requiring two layers to press together. Both technologies predate the iPhone. Multi-touch depends on the sensor, controller, and software, not the word “capacitive” alone. Slow menus can also reflect software or processing delays; do not attribute every lag to the touch sensor. Apple’s [2007 announcement](https://www.apple.com/newsroom/2007/01/09Apple-Reinvents-the-Phone-with-iPhone/) documents finger-operated Multi-Touch. Technical background: [TI’s comparison, pp. 29–30](https://www.ti.com/lit/an/slyt511/slyt511.pdf).

**12. Capacitive touch in the kitchen (PDF page 19).** Ask: “You need to turn down a boiling pan. Your hands are wet. What would you want from the controls?” Discuss tactile landmarks, finding the right cooking zone, feedback, accidental touches during wiping, and ease of cleaning. The photo shows capacitive touch buttons on glass, not a phone-like graphical touchscreen. It is Figure 1 in [TI’s December 2017 article](https://www.ti.com/document-viewer/lit/html/SSZT855/GUID-F9F84AE3-1794-4CE3-9444-61C3FC7EA523). The source promotes moisture/food rejection, so do not claim that this photographed unit fails when wet. Those are conditions to test, not observed failures. The teaching point is that an input method’s value depends on its task and environment. Loosely connect to user control, feedback, error prevention, and universal usability.

## Bilingual contact sorting, 52–57 minutes

**13. Interface language and name sorting (PDF pages 20–21).** Task: find a Chinese contact through the alphabetical index while keeping menus in English. The iPhone screenshot shows Chinese contacts grouped under “#” rather than their Pinyin initials. It comes from 觉主’s [May 16, 2016 first-person article](https://sspai.com/post/34222), so it documents historical behavior, not a test of the current iOS version. The original pixelated redactions remain intact. More precisely, the useful Pinyin grouping/index is missing; avoid saying the contacts have no ordering whatsoever.

The Android screenshot shows 李四 under L, 王五 under W, and 张三 under Z alongside Latin-script names. It is the right-hand result from [Ranmocy Sheng’s MonkeyTree repository](https://github.com/ranmocy/MonkeyTree). The app adds phonetic names and sets their phonetic type to PINYIN before the operating system sorts them. The developer’s “After” annotation is preserved. Do not present this as an untouched Android default or a same-contact-list comparison with the iPhone. Exact device, OS, and Contacts version are not established by the screenshot. The screenshot filename mentions 5x but is not sufficient to establish a device model.

The evidence does not support a universal “iPhone ignores bilingual users; Android always gets it right” claim. [Android’s Contacts API](https://developer.android.com/reference/android/provider/ContactsContract.ContactNameColumns#SORT_KEY_PRIMARY) documents Pinyin sort keys, but visible behavior depends on app, locale preferences, and contact metadata. A [March 2023 first-person Android 13 report](https://android.stackexchange.com/questions/251008/sort-contacts-by-hanyu-pinyin) found ASUS working with English, while Google and Samsung required Simplified Chinese as the second preferred language. iPhone can also sort these names after phonetic fields are added, as the 2016 article demonstrates. These workarounds expose a design question: why are interface language and a bilingual person’s preferred name ordering coupled, and how discoverable are the controls?

Discussion: ask students to find the expected sections for 韦 (Wei), 尹 (Yin), and 乔 (Qiao) on the first screen, then 李 (Li), 王 (Wang), and 张 (Zhang) on the second. A fair follow-up test uses identical synthetic contacts on named OS/app versions, English UI on both, recorded secondary-language settings, and no prefilled phonetic fields. Include multilingual users and surnames with multiple pronunciations.

## Per-page cues for the examples

The following cues accompany the projected example pages. Titles appear on the slides; the other text stays here for presentation. Source links remain in the example discussions above, the asset provenance files.

### PDF page 3: Liquid Glass Beta 1

Three full phone screens appear side by side, left to right:

- Beto Moedano’s notification screen. Read “Sign up for labs.” Ask how wallpaper affects readability. Original June 9, 2025 post.
- Holly’s Control Center. Find the playback controls and flashlight. Ask which shapes are controls and which belong to the background. Original June 10, 2025 post.
- Jay Peters’ beta 1 Control Center. Find the flashlight and screen-recording controls. Source: The Verge, June 23, 2025.

All three depict the original iOS 26 Liquid Glass beta era. The two social posts are contemporaneous complaints; their screens do not display build numbers. These are separate captures, not three states from the same device. Source links are in the example discussion above.

### PDF page 4: Liquid Glass: user choice

Task: Choose a glass appearance that is comfortable to read.

LATER USER CONTROL · iOS 27 transparency slider, WWDC26

A slider lets users choose between ultra clear and fully tinted.

What should the default be? Who benefits from changing it?

Apple, WWDC26, 23:08: Podcasts demo. Earlier: iOS 26.1 Clear/Tinted options. Different app and later release.

### PDF page 5: Apple Accessibility Reader

Task: Read the same passage at a comfortable size.

BEFORE · Original document on iPhone

A full page of small print fills the original document view.

What would you change to make this task easier?

Apple, May 13, 2025. Official iPhone comparison of The Odyssey before and with Accessibility Reader. Mode change.

### PDF page 6: Apple Accessibility Reader

Task: Read the same passage at a comfortable size.

AFTER · Accessibility Reader on iPhone

Larger text and spacing create a focused reading view.

What must survive when content reflows or is read aloud?

Apple, May 13, 2025. Official iPhone comparison of The Odyssey before and with Accessibility Reader. Mode change.

### PDF page 7: Google Maps incident reporting

Task: Choose the correct incident category.

BEFORE · Reporting menu, October 2019

Seven compact icon-and-label choices in three columns.

What would you change to make this task easier?

Google, Oct 2019 (iOS) Google, Jul 2024 (Android). Full phone screens. iOS / Android.

### PDF page 8: Google Maps incident reporting

Task: Choose the correct incident category.

AFTER · Larger targets, July 2024

Larger tiles use two columns. More choices continue below.

What do larger targets gain, and how much space do they cost?

Google, Oct 2019 (iOS) Google, Jul 2024 (Android). Full phone screens. iOS / Android.

### PDF page 9: Android delivery notifications

Task: Tell how far an order has progressed.

BEFORE · Standard notification

Text names the current stage: “on its way.”

What would you change to make this task easier?

Google Android codelab: Jetsnack before/after migration. Official sample app, not a commercial delivery service.

### PDF page 10: Android delivery notifications

Task: Tell how far an order has progressed.

AFTER · ProgressStyle, Android 16

A visual tracker adds progress through the delivery stage.

What should change if the tracking data becomes stale?

Google Android codelab: Jetsnack before/after migration. Official sample app, not a commercial delivery service.

### PDF page 11: Discord: finding messages

BEFORE · December 2023: Servers and Messages occupy separate bottom tabs. Ask where to look for a DM.

### PDF page 12: Discord: finding messages

AFTER · May 2024: the merged Home contains both. Discuss cross-device consistency and the cost of moving a familiar control.


### PDF page 13: Chrome suspicious-notification warning

Task: Decide whether to open a notification claiming a virus.

BEFORE · Content view

A deceptive message urges the user to scan the device.

What could go wrong if the user follows this message?

Chrome, May 8, 2025. Two views of the same feature, not historical releases. Content view follows “Show notification.”

### PDF page 14: Chrome suspicious-notification warning

Task: Decide whether to open a notification claiming a virus.

AFTER · Protective warning view

Chrome hides flagged content behind a warning and a choice.

Which mistaken action does the warning try to prevent?

Chrome, May 8, 2025. Two views of the same feature, not historical releases. Content view follows “Show notification.”

### PDF page 15: Instagram: moving familiar controls

BEFORE · Old navigation in the designer’s opt-in demo. Identify the actual bottom bar, not the preview inside the announcement banner. Find DMs, Create, and Reels.

### PDF page 16: Instagram: moving familiar controls

AFTER · Meta’s September 2025 Home screen. Compare DMs at bottom center, Reels second, and Create top left. Discuss reach and relearning.


## Image presentation and source limits

Full phone screens appear for Liquid Glass complaints and Control Center, Accessibility Reader, Maps, Chrome warnings, Discord, and Instagram. Before and after remain on separate pages. Google’s Android notification examples are published as notification excerpts. Apple’s slider demo only shows the lower interface. Those source limits are preserved. The Maps demos and Chrome warning originals have no sharper version among the checked originals. Source pixels are not reconstructed or artificially upscaled.

### PDF page 17: Uber Eats: order confirmation

Describe the older progress-indicator-and-Undo state aloud, then reveal the original 2023 phone screenshot. Ask what waiting, Confirm, and Undo each do. The source shows six seconds remaining, not a verified 15-second current default. See discussion 10 for provenance and limitations.

### PDF page 18: Resistive touch vs capacitive touch

An older Delta 737-800 seatback display appears on the left; the original iPhone finger-typing illustration is on the right. Both screens remain fully visible. Compare pressing, feedback, and context. See discussion 11 for sources and technology qualifications.

### PDF page 19: Capacitive touch in the kitchen

A finger operates glass cooktop controls. Ask whether the same input method fits this environment and how students would evaluate it. The photograph is not evidence of malfunction.

### PDF page 20: iPhone: bilingual contact sorting

Full 640 × 1136 screenshot with English menus, Chinese contacts, and hash headings. Historical 2016 example. Ask what happened to Pinyin-based index navigation.

### PDF page 21: Android: Pinyin sorting after setup

One complete Android screenshot, extracted in the slide layout from the right half of the developer’s comparison. English menus remain visible, with Chinese names under L, W, and Z. State aloud that phonetic-name fields were added by MonkeyTree. This is an example of the configured outcome, not evidence of the platform’s default.
