// CSE 416-03 Fall 2026. Compile with: typst compile SE26fa-04-UIUX.typ
// Teaching cues and source details: SE26fa-04-UIUX-notes.md, img/uiux/SOURCES.md
#let orange = rgb("#E67E22")
#let teal = rgb("#48C9B0")
#let tan = rgb("#C9B48A")
#let ink = rgb("#4A4A4A")
#let box-bg = rgb("#F7F4EE")

#set page(
  paper: "presentation-16-9",
  margin: (x: 1.15cm, top: 0.85cm, bottom: 1.05cm),
  background: place(bottom, rect(width: 100%, height: 8pt, fill: teal)),
)
#set text(font: "Helvetica Neue", size: 20pt, fill: ink)
#set par(leading: 1.15em)
#set list(indent: 0.15em, marker: ([●], [○]), spacing: 1.15em)
#show heading: set text(fill: orange, weight: "bold")
#show link: set text(fill: rgb("#1A73E8"))

#let triple-line = align(center, stack(
  dir: ttb,
  spacing: 4pt,
  line(length: 86%, stroke: 0.8pt + teal),
  line(length: 86%, stroke: 2.6pt + teal),
  line(length: 86%, stroke: 0.8pt + teal),
))

#let title-slide(title, subtitle) = page(
  margin: 0cm,
  background: none,
  {
    set align(center)
    v(0.7cm)
    triple-line
    v(2.15cm)
    text(size: 38pt, weight: "bold", fill: orange, title)
    v(0.65cm)
    grid(
      columns: (1fr, auto, 1fr),
      align: horizon,
      align(right, rect(width: 1.6cm, height: 7pt, fill: tan, radius: 1pt)),
      pad(x: 0.5cm, text(size: 20pt, fill: ink, subtitle)),
      align(left, rect(width: 1.6cm, height: 7pt, fill: tan, radius: 1pt)),
    )
    v(2.15cm)
    triple-line
  },
)


#set document(title: "UI/UX: Learning from examples", author: "Shuai Mu")
#let muted = luma(110)

#let slide(title, body, cite: none) = page[
  #set par(leading: 0.8em)
  #set list(spacing: 0.85em)
  #text(size: 28pt, weight: "bold", fill: orange, title)
  #v(0.45cm)
  #body
  #if cite != none { place(bottom + left, text(size: 9.65pt, fill: muted, cite)) }
]
#let label(body) = text(size: 13.15pt, weight: "bold", fill: teal, body)
#let prompt(body) = {v(16.66pt); text(size: 18.5pt, fill: ink, weight: "bold", body)}
#let photo(name, w: 100%, h: 278.88pt) = {
  if name == "airbnb.jpg" {
    block(width: 100%, height: h, clip: true)[
      #place(top + center, dy: -42.10pt, image("img/uiux/airbnb.jpg", width: 298.18pt, height: 609.95pt))
    ]
  } else if name == "spotify.jpg" {
    block(width: 100%, height: h, clip: true)[
      #place(top + left, dx: -585.83pt, image("img/uiux/spotify.jpg", width: 982.23pt, height: 375.00pt))
    ]
  } else {
    image("img/uiux/" + name, width: w, height: h, fit: "contain")
  }
}
#let case(title, name, body, question, cite, wide: false) = slide(title, [
  #if wide {
    photo(name, h: 197.32pt)
    v(10.52pt)
    text(size: 18.42pt, body)
    prompt(question)
  } else {
    grid(columns: (1.16fr, 1fr), gutter: 26.31pt,
      photo(name, h: 293.79pt),
      [#set text(size: 19.29pt)
       #body #prompt(question)])
  }
], cite: cite)
#let nn = link("https://www.nngroup.com/articles/ten-usability-heuristics/")[Nielsen Norman Group: usability heuristics]
#let gmail = "https://blog.google/products-and-platforms/products/gmail/one-stop-purchase-tracking-in-gmail/"
#let apple = "https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/"
#let airbnb = "https://news.airbnb.com/product-releases/airbnb-2025-summer-release"
#let android = "https://blog.google/products-and-platforms/platforms/android/android-16/"
#let spotify = "https://newsroom.spotify.com/2025-05-07/experience-a-new-dimension-of-music-discovery-with-more-controls-and-enhanced-tools/"
#let chrome = "https://blog.google/security/the-multi-layered-defenses-that-harden-chrome-against-abusive-notifications/"
#let reader = "https://www.apple.com/newsroom/2025/05/apple-unveils-powerful-accessibility-features-coming-later-this-year/"
#let maps = "https://blog.google/products-and-platforms/products/maps/maps-waze-new-features-information-on-the-go/"


#let asset-sizes = (
  "bilingual/android-phonetic-comparison.png": (1830, 1624),
  "touchscreens/iphone-2007-guide-page17.png": (1620, 1944),
  "discord-navigation-2023.png": (739, 1600),
  "discord-navigation-2024.png": (739, 1600),
  "instagram-navigation-before.png": (1920, 1080),
  "instagram-navigation-2025.png": (2880, 1620),

  "fullscreen/notifications-original.png": (738, 1600),
  "fullscreen/controls-original.png": (1320, 1276),
  "fullscreen/airbnb-2021-2x.png": (852, 1593),
  "fullscreen/reader-press-2x.png": (1960, 1400),
  "fullscreen/chrome-undo-original.png": (1920, 1080),
  "fullscreen/spotify-queue-2025.png": (657, 700),
  "liquid-glass-candidates/notifications-beto.jpg": (554, 1200),
  "liquid-glass-candidates/control-holly.jpg": (1200, 1160),
  "liquid-glass-candidates/verge-beta1.png": (1206, 2622),
  "liquid-glass-candidates/verge-beta2.png": (1206, 2622),
  "ibm-confirmation-before.png": (896, 896),
  "ibm-confirmation-after.png": (896, 896),
  "apple-glass-ios26.png": (1920, 1080),
  "apple-glass-ios27-wwdc.png": (1920, 1080),
  "apple-glass-slider.png": (1920, 1080),
  "booking-payment.png": (1239, 764),
  "booking-confirmation.png": (925, 1197),
  "chrome-unshielded.png": (350, 631),
  "chrome-warning.png": (369, 636),
  "spotify.jpg": (1920, 733),
  "chrome-undo.webp": (1200, 752),
  "apple-tabs.jpg": (1306, 734),
  "gmail-2022.png": (896, 1956),
  "figma-exploration.png": (1608, 1072),
  "android-after.png": (834, 288),
  "apple-music-18-26.jpg": (1300, 1218),
  "android.png": (1920, 1080),
  "airbnb.jpg": (790, 1616),
  "figma.png": (1920, 1080),
  "reader.jpg": (980, 700),
  "chrome-action.webp": (1200, 675),
  "gmail.webp": (1200, 1094),
  "chrome-legacy.jpeg": (2048, 970),
  "figma-final.png": (1608, 1072),
  "maps-2019.png": (800, 800),
  "airbnb-2021.png": (426, 797),
  "spotify-2026.png": (720, 900),
  "reader-comparison.png": (752, 446),
  "maps.png": (850, 850),
  "android-before.png": (1256, 580),
  "chrome-permission.webp": (1200, 477),
)

// Crop only for magnification. Source screenshot pixels remain unchanged.
#let detail(name, box, w: 776pt, h: 380pt) = {
  let fw = asset-sizes.at(name).at(0)
  let fh = asset-sizes.at(name).at(1)
  let bw = box.at(2) - box.at(0)
  let bh = box.at(3) - box.at(1)
  let scale = calc.min(w / bw, h / bh)
  align(center + horizon, block(width: bw * scale, height: bh * scale, clip: true)[
    #place(top + left, dx: -box.at(0)*scale, dy: -box.at(1)*scale,
      image("img/uiux/" + name, width: fw*scale, height: fh*scale))
  ])
}
// Example pages show the title and screenshots. Other arguments retain teaching cues.
#let example-slide(title, task, stage, visual, caption, question, cite) = page(
  margin: (x: 1.15cm, top: 0.85cm, bottom: 16pt),
  background: none,
  [
    #text(size: 28pt, weight: "bold", fill: orange, title)
    #place(top + center, dy: 48pt,
      block(width: 100%, height: 380pt, align(center + horizon, visual)))
  ],
)
#let comparison(title, task, before-label, after-label, before-image, after-image,
                before-text, after-text, question, cite,
                before-question: [What would you change to make this task easier?]) = {
  example-slide(title, task, before-label, before-image, before-text, before-question, cite)
  example-slide(title, task, after-label, after-image, after-text, question, cite)
}
#let gmail-before = "https://blog.google/products-and-platforms/products/gmail/package-tracking/"
#let airbnb-before = "https://www.adamshutsa.com/arrival-guide/"
#let apple-beta = "https://www.theverge.com/news/691540/apple-ios-26-liquid-glass-control-center-fixed-beta"
#let apple-beto = "https://twitter.com/betomoedano/status/1932189570604437886"
#let apple-holly = "https://twitter.com/AnxiousHolly/status/1932330130967257360"
#let apple-compare = "https://developer.apple.com/videos/play/wwdc2026/102/"
#let android-compare = "https://developer.android.com/devsite/codelabs/notifications-rich-experience-live-updates"
#let spotify-after = "https://newsroom.spotify.com/2026-05-28/playlist-folders-mobile-queue-controls-updates/"
#let chrome-action = "https://blog.google/products-and-platforms/products/chrome/google-chrome-safety-update-september-2024/"
#let chrome-before = "https://www.usenix.org/system/files/sec21_slides_bilogrevic.pdf"
#let chrome-after = "https://developer.chrome.com/blog/notification-prompts-android"
#let reader-compare = "https://mcmw.abilitynet.org.uk/how-to-make-reading-or-listening-to-content-easier-on-your-apple-computer-with-the-accessibility-reader-app-in-macos-26-tahoe"
#let maps-before = "https://blog.google/products-and-platforms/products/maps/new-ways-report-driving-incidents-google-maps/"

#let golden-url = "https://www.cs.umd.edu/users/ben/goldenrules.html"
#let golden = link(golden-url)[Ben Shneiderman: The Eight Golden Rules of Interface Design. DTUI, 6th ed., §3.3.4 (2016).]
#let ibm-confirmation = "https://v10.carbondesignsystem.com/case-studies/ibm-commerce-platform/"
#let chrome-warning = "https://blog.google/chromium/fighting-unwanted-notifications-wi/"

// 1
#title-slide[UI/UX: learning from examples][CSE-416-03  ·  Sep 21, 2026]


// 2
#slide[Learning through examples][
  #v(70pt)
  #align(center)[
    #text(size: 30pt)[We’ll learn through examples#linebreak()and apply our common sense.]
  ]
]


// 4
#example-slide([Liquid Glass Beta 1],
  [Read the lab notification, then find the playback and flashlight controls.],
  [iOS 26 first developer beta, June 2025],
  grid(columns: (1fr, 1fr, 1fr), column-gutter: 24pt, align: center + horizon,
    detail("fullscreen/notifications-original.png", (0, 0, 738, 1600), w: 230pt),
    detail("fullscreen/controls-original.png", (350, 0, 975, 1258), w: 230pt),
    detail("liquid-glass-candidates/verge-beta1.png", (0, 0, 1206, 2622), w: 230pt)),
  [Left: washed-out notifications. Center and right: Control Center over Home Screen content.],
  [Which text and controls are difficult to distinguish from the background?],
  [Left: #link(apple-beto)[Beto Moedano, June 9, 2025]. Center: #link(apple-holly)[Holly, June 10, 2025]. Right: #link(apple-beta)[Jay Peters / The Verge, June 23, 2025]. Full phone screens.])

#example-slide([Liquid Glass: user choice],
  [Choose a glass appearance that is comfortable to read.],
  [LATER USER CONTROL · iOS 27 transparency slider, WWDC26],
  detail("apple-glass-slider.png", (360, 230, 1560, 950)),
  [A slider lets users choose between ultra clear and fully tinted.],
  [What should the default be? Who benefits from changing it?],
  [#link(apple-compare)[Apple, WWDC26, 23:08: Podcasts demo]. Earlier: #link("https://support.apple.com/en-gb/123075")[iOS 26.1 Clear/Tinted options]. Different app and later release.])


// 5
#comparison([Apple Accessibility Reader], [Read the same passage at a comfortable size.],
  [BEFORE · Original document on iPhone], [AFTER · Accessibility Reader on iPhone],
  detail("fullscreen/reader-press-2x.png", (350, 90, 950, 1310)),
  detail("fullscreen/reader-press-2x.png", (1020, 90, 1620, 1310)),
  [A full page of small print fills the original document view.],
  [Larger text and spacing create a focused reading view.],
  [What must survive when content reflows or is read aloud?],
  [#link(reader)[Apple, May 13, 2025]. Official iPhone comparison showing The Odyssey before and with Accessibility Reader. Mode change.])


// 6
#comparison([Google Maps incident reporting], [Choose the correct incident category.],
  [BEFORE · Reporting menu, October 2019], [AFTER · Larger targets, July 2024],
  detail("maps-2019.png", (229, 55, 573, 742)),
  detail("maps.png", (232, 9, 616, 845)),
  [Seven compact icon-and-label choices in three columns.],
  [Larger tiles use two columns. More choices continue below.],
  [What do larger targets gain, and how much space do they cost?],
  [#link(maps-before)[Google, Oct 2019 (iOS)] #h(6pt) #link(maps)[Google, Jul 2024 (Android)]. Full phone screens. iOS / Android.])


// 7
#comparison([Android delivery notifications], [Tell how far an order has progressed.],
  [BEFORE · Standard notification], [AFTER · ProgressStyle, Android 16],
  detail("android-before.png", (0, 0, 1256, 389), w: 630pt),
  detail("android-after.png", (0, 0, 834, 274), w: 630pt),
  [Text names the current stage: “on its way.”],
  [A visual tracker adds progress through the delivery stage.],
  [What should change if the tracking data becomes stale?],
  [#link(android-compare)[Google Android codelab: Jetsnack before/after migration]. Official sample app, not a commercial delivery service.])


// 8
#comparison([Discord: finding messages], [Switch between a server and a direct message.],
  [BEFORE · Separate tabs, December 2023], [AFTER · Merged Home, May 2024],
  image("img/uiux/discord-navigation-2023.png", height: 380pt),
  image("img/uiux/discord-navigation-2024.png", height: 380pt),
  [Servers and Messages occupy separate tabs.],
  [DMs return to the server rail inside Home.],
  [When does consistency across devices outweigh a dedicated shortcut?],
  [#link("https://discord.com/blog/improving-our-mobile-experience")[Discord, December 2023] and #link("https://discord.com/blog/refining-discords-mobile-experience-with-your-feedback")[May 2024]. Official full-screen previews. Light and dark themes differ.],
  before-question: [Where would you look for a DM while browsing this server?])

// 9
#comparison([Chrome suspicious-notification warning], [Decide whether to open a notification claiming a virus.],
  [BEFORE · Content view], [AFTER · Protective warning view],
  detail("chrome-unshielded.png", (35, 19, 328, 625)),
  detail("chrome-warning.png", (45, 20, 343, 625)),
  [A deceptive message urges the user to scan the device.],
  [Chrome hides flagged content behind a warning and a choice.],
  [Which mistaken action does the warning try to prevent?],
  [#link(chrome-warning)[Chrome, May 8, 2025]. Two views of the same feature, not historical releases. Content view follows “Show notification.”],
  before-question: [What could go wrong if the user follows this message?])


// 13
#comparison([Instagram: moving familiar controls], [Open messages, find Reels, and create a post.],
  [BEFORE · Navigation before opting in], [AFTER · Navigation announced September 2025],
  detail("instagram-navigation-before.png", (753, 112, 1167, 968)),
  detail("instagram-navigation-2025.png", (414, 198, 981, 1424)),
  [DMs sit at the top right; Create sits in the bottom bar.],
  [DMs move to the bottom center and Create moves to the top left.],
  [Whose task becomes easier, and what habits must users relearn?],
  [#link("https://thinkgabrielalves.com/portfolio/instagram-new-nav/")[Gabe Alves, Instagram design case study] and #link("https://about.fb.com/news/2025/09/in-india-instagram-debuts-a-reels-first-experience-for-its-mobile-app/")[Meta, September 2025]. Designer demo versus official release image. Different sample feeds.])

// Uber Eats: documented screenshot; earlier behavior discussed in teaching notes.
#example-slide([Uber Eats: order confirmation],
  [Review an order after tapping Place order.], [Documented September 2023 capture],
  image("img/uiux/fullscreen/uber-eats-confirm-2023.jpg", height: 380pt),
  [Confirm immediately, wait for the countdown, or Undo.],
  [Does the countdown communicate a chance to recover, or pressure to act?],
  [#link("https://www.linkedin.com/posts/robertcmeza_would-this-be-yet-another-dark-pattern-activity-7110675422853390336-JkHH")[Robert Meza, September 21, 2023]. Original annotations and redactions retained.])

// Different products and contexts, shown together for an input-method comparison.
#example-slide([Resistive touch vs capacitive touch],
  [Compare selecting a movie on a seatback screen with finger interaction on an iPhone.],
  [Older Delta 737-800 seatback system and original iPhone],
  grid(columns: (480pt, 260pt), gutter: 28pt, align: center + horizon,
    image("img/uiux/touchscreens/delta-737-seatback-2017.jpg", width: 480pt, height: 360pt, fit: "contain"),
    detail("touchscreens/iphone-2007-guide-page17.png", (400, 1170, 970, 1804), w: 260pt, h: 365pt)),
  [An older airline resistive touchscreen beside the original capacitive iPhone.],
  [How do pressure, touch feedback, and the surrounding environment affect interaction?],
  [Seatback photo: The Points Guy, Delta 737-800 review, 2017. iPhone: Apple User’s Guide, 2007, p. 17. Sources and technology qualifications in teaching notes.])

#example-slide([Capacitive touch in the kitchen],
  [Reduce the heat while cooking.], [Capacitive cooktop controls],
  image("img/uiux/touchscreens/capacitive-cooktop-ti.jpg", width: 570pt, height: 380pt, fit: "contain"),
  [Touch controls on the glass surface of a cooktop.],
  [What changes when hands are wet, attention is divided, or a pan boils over?],
  [Texas Instruments, Cooktops with capacitive touch technology, December 2017, Figure 1.])

#example-slide([iPhone: bilingual contact sorting],
  [Find a Chinese contact by the initial of their surname.],
  [English interface, published May 2016],
  image("img/uiux/bilingual/iphone-english-chinese-2016.jpg", height: 380pt),
  [Chinese contacts appear under hash headings rather than Pinyin initials.],
  [Should choosing English for menus change how Chinese names are indexed?],
  [觉主 / 少数派, May 16, 2016. Original screenshot and redactions. Historical behavior, not a current-version test.])

#example-slide([Android: Pinyin sorting after setup],
  [Find Li, Wang, and Zhang while keeping the interface in English.],
  [Contacts after MonkeyTree adds phonetic-name fields],
  detail("bilingual/android-phonetic-comparison.png", (920, 10, 1820, 1614), w: 400pt, h: 380pt),
  [Chinese names appear under L, W, and Z alongside Latin-script contacts.],
  [Why should the user need extra setup to preserve their preferred name ordering?],
  [Ranmocy Sheng / MonkeyTree, developer’s original result screenshot. Right half of a published comparison. This is configured behavior, not proof of Android defaults.])
