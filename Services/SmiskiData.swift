//
//  SmiskiData.swift
//  Orca

import Foundation

struct SmiskiSeriesInfo: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let figures: [SmiskiFigureInfo]

    var regularFigures: [SmiskiFigureInfo] { figures.filter { !$0.isSecret } }
    var secretFigure: SmiskiFigureInfo? { figures.first { $0.isSecret } }
}

struct SmiskiFigureInfo: Identifiable {
    let id: String
    let name: String
    let isSecret: Bool
    let imageURL: String?
}

private let s1 = "https://smiski.com/wp-content/uploads/2016/03/"
private let s2 = "https://smiski.com/wp-content/uploads/2016/03/"
private let s3 = "https://smiski.com/e/wp-content/uploads/2016/09/"
private let s4 = "https://smiski.com/e/wp-content/uploads/2017/02/"
private let living = "https://aa243gcvbg.smartrelease.jp/wp-content/uploads/2018/08/"
private let bath = "https://smiski.com/e/wp-content/uploads/2017/10/"
private let toilet = "https://smiski.com/e/wp-content/uploads/2017/10/"
private let bed = "https://smiski.com/e/wp-content/uploads/2019/07/"
private let yoga = "https://smiski.com/e/wp-content/uploads/2019/09/"
private let cheer = "https://smiski.com/e/wp-content/uploads/2020/12/"
private let museum = "https://smiski.com/e/wp-content/uploads/2020/12/"
private let work = "https://smiski.com/wp-content/uploads/2022/02/"
private let dressing = "https://smiski.com/e/wp-content/uploads/2022/10/"
private let exercising = "https://smiski.com/e/wp-content/uploads/2023/05/"
private let moving = "https://smiski.com/e/wp-content/uploads/2024/01/"
private let hippers = "https://smiski.com/e/wp-content/uploads/2024/09/"
private let sunday = "https://smiski.com/e/wp-content/uploads/2025/02/"
private let birthday = "https://smiski.com/e/wp-content/uploads/2025/09/"
private let construction = "https://smiski.com/e/wp-content/uploads/2026/06/"

enum SmiskiCatalog {
    static let allSeries: [SmiskiSeriesInfo] = [
        SmiskiSeriesInfo(id: "series1", name: "Series 1", emoji: "🌟", figures: [
            SmiskiFigureInfo(id: "series1_01", name: "Hugging Knees",  isSecret: false, imageURL: s1 + "s1_01.png"),
            SmiskiFigureInfo(id: "series1_02", name: "Sitting",         isSecret: false, imageURL: s1 + "s1_02.png"),
            SmiskiFigureInfo(id: "series1_03", name: "Looking Back",    isSecret: false, imageURL: s1 + "s1_03.png"),
            SmiskiFigureInfo(id: "series1_04", name: "Lounging",        isSecret: false, imageURL: s1 + "s1_04.png"),
            SmiskiFigureInfo(id: "series1_05", name: "Hiding",          isSecret: false, imageURL: s1 + "s1_05.png"),
            SmiskiFigureInfo(id: "series1_06", name: "Peeking",         isSecret: false, imageURL: s1 + "s1_06.png"),
            SmiskiFigureInfo(id: "series1_s",  name: "The Scream ✦",    isSecret: true,  imageURL: s1 + "s1_secret.png"),
        ]),
        SmiskiSeriesInfo(id: "series2", name: "Series 2", emoji: "✨", figures: [
            SmiskiFigureInfo(id: "series2_01", name: "Kneeling",        isSecret: false, imageURL: s2 + "s2_01.png"),
            SmiskiFigureInfo(id: "series2_02", name: "Climbing",        isSecret: false, imageURL: s2 + "s2_02.png"),
            SmiskiFigureInfo(id: "series2_03", name: "Daydreaming",     isSecret: false, imageURL: s2 + "s2_03.png"),
            SmiskiFigureInfo(id: "series2_04", name: "Pushing",         isSecret: false, imageURL: s2 + "s2_04.png"),
            SmiskiFigureInfo(id: "series2_05", name: "Peeking",         isSecret: false, imageURL: s2 + "s2_05.png"),
            SmiskiFigureInfo(id: "series2_06", name: "Listening",       isSecret: false, imageURL: s2 + "s2_06.png"),
            SmiskiFigureInfo(id: "series2_s",  name: "Birth of Venus ✦",isSecret: true,  imageURL: s2 + "s2_secret.png"),
        ]),
        SmiskiSeriesInfo(id: "series3", name: "Series 3", emoji: "💫", figures: [
            SmiskiFigureInfo(id: "series3_01", name: "Bridge",          isSecret: false, imageURL: s3 + "3_3.png"),
            SmiskiFigureInfo(id: "series3_02", name: "Peeking",         isSecret: false, imageURL: s3 + "3_4.png"),
            SmiskiFigureInfo(id: "series3_03", name: "Climbing",        isSecret: false, imageURL: s3 + "3_5.png"),
            SmiskiFigureInfo(id: "series3_04", name: "Little",          isSecret: false, imageURL: s3 + "3_6.png"),
            SmiskiFigureInfo(id: "series3_05", name: "Hiding",          isSecret: false, imageURL: s3 + "3_7.png"),
            SmiskiFigureInfo(id: "series3_06", name: "Handstand",       isSecret: false, imageURL: s3 + "3_8.png"),
            SmiskiFigureInfo(id: "series3_s",  name: "The Thinker ✦",   isSecret: true,  imageURL: s3 + "s3_secret.png"),
        ]),
        SmiskiSeriesInfo(id: "series4", name: "Series 4", emoji: "🌙", figures: [
            SmiskiFigureInfo(id: "series4_01", name: "Sneaking",        isSecret: false, imageURL: s4 + "3_3.png"),
            SmiskiFigureInfo(id: "series4_02", name: "Scared",          isSecret: false, imageURL: s4 + "3_4.png"),
            SmiskiFigureInfo(id: "series4_03", name: "Relaxing",        isSecret: false, imageURL: s4 + "3_5.png"),
            SmiskiFigureInfo(id: "series4_04", name: "Lazy",            isSecret: false, imageURL: s4 + "3_6.png"),
            SmiskiFigureInfo(id: "series4_05", name: "Stuck",           isSecret: false, imageURL: s4 + "3_7.png"),
            SmiskiFigureInfo(id: "series4_06", name: "Defeated",        isSecret: false, imageURL: s4 + "3_8.png"),
            SmiskiFigureInfo(id: "series4_s",  name: "Twin Angels ✦",   isSecret: true,  imageURL: s4 + "s3_secret-1.png"),
        ]),
        SmiskiSeriesInfo(id: "living", name: "Living Series", emoji: "🏠", figures: [
            SmiskiFigureInfo(id: "living_01", name: "Daydreaming",      isSecret: false, imageURL: living + "05.png"),
            SmiskiFigureInfo(id: "living_02", name: "Playing",          isSecret: false, imageURL: living + "04.png"),
            SmiskiFigureInfo(id: "living_03", name: "Hiding",           isSecret: false, imageURL: living + "02.png"),
            SmiskiFigureInfo(id: "living_04", name: "Nap Time",         isSecret: false, imageURL: living + "03.png"),
            SmiskiFigureInfo(id: "living_05", name: "Thinking",         isSecret: false, imageURL: living + "01.png"),
            SmiskiFigureInfo(id: "living_06", name: "Lifting",          isSecret: false, imageURL: living + "06.png"),
            SmiskiFigureInfo(id: "living_s",  name: "Sunflower ✦",      isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "bath", name: "Bath Series", emoji: "🛁", figures: [
            SmiskiFigureInfo(id: "bath_01", name: "Shampooing",         isSecret: false, imageURL: bath + "awadateski.png"),
            SmiskiFigureInfo(id: "bath_02", name: "Not Looking",        isSecret: false, imageURL: bath + "tereski.png"),
            SmiskiFigureInfo(id: "bath_03", name: "Scrubbing",          isSecret: false, imageURL: bath + "araikkoski.png"),
            SmiskiFigureInfo(id: "bath_04", name: "With Duck",          isSecret: false, imageURL: bath + "ahirumochiski.png"),
            SmiskiFigureInfo(id: "bath_05", name: "Dazed",              isSecret: false, imageURL: bath + "noboseski.png"),
            SmiskiFigureInfo(id: "bath_06", name: "Looking",            isSecret: false, imageURL: bath + "mitaski.png"),
            SmiskiFigureInfo(id: "bath_s",  name: "Water Droplet ✦",    isSecret: true,  imageURL: bath + "bath_secret.png"),
        ]),
        SmiskiSeriesInfo(id: "toilet", name: "Toilet Series", emoji: "🚿", figures: [
            SmiskiFigureInfo(id: "toilet_01", name: "Peek-A-Boo",       isSecret: false, imageURL: toilet + "hyokkoriski.png"),
            SmiskiFigureInfo(id: "toilet_02", name: "Little (Smelly)",  isSecret: false, imageURL: nil),
            SmiskiFigureInfo(id: "toilet_03", name: "Squatting",        isSecret: false, imageURL: toilet + "shagamiski.png"),
            SmiskiFigureInfo(id: "toilet_04", name: "Helping Out",      isSecret: false, imageURL: toilet + "sashidashiski.png"),
            SmiskiFigureInfo(id: "toilet_05", name: "Resting",          isSecret: false, imageURL: toilet + "koshikakeski.png"),
            SmiskiFigureInfo(id: "toilet_06", name: "Holding In",       isSecret: false, imageURL: toilet + "gamanski.png"),
            SmiskiFigureInfo(id: "toilet_s",  name: "Water Fountain ✦", isSecret: true,  imageURL: toilet + "toilet_secret.png"),
        ]),
        SmiskiSeriesInfo(id: "bed", name: "Bed Series", emoji: "🛏️", figures: [
            SmiskiFigureInfo(id: "bed_01", name: "Before Rest",         isSecret: false, imageURL: bed + "img_bed_products_01.png"),
            SmiskiFigureInfo(id: "bed_02", name: "Sleepy",              isSecret: false, imageURL: bed + "img_bed_products_02.png"),
            SmiskiFigureInfo(id: "bed_03", name: "Co-Sleeping",         isSecret: false, imageURL: bed + "img_bed_products_03.png"),
            SmiskiFigureInfo(id: "bed_04", name: "Reading",             isSecret: false, imageURL: bed + "img_bed_products_04.png"),
            SmiskiFigureInfo(id: "bed_05", name: "At Sleep",            isSecret: false, imageURL: bed + "img_bed_products_05.png"),
            SmiskiFigureInfo(id: "bed_06", name: "Fussing",             isSecret: false, imageURL: bed + "img_bed_products_06.png"),
            SmiskiFigureInfo(id: "bed_s",  name: "Crescent Moon ✦",     isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "yoga", name: "Yoga Series", emoji: "🧘", figures: [
            SmiskiFigureInfo(id: "yoga_01", name: "Lotus Pose",         isSecret: false, imageURL: yoga + "img_yoga_01.png"),
            SmiskiFigureInfo(id: "yoga_02", name: "Twist Pose",         isSecret: false, imageURL: yoga + "img_yoga_02.png"),
            SmiskiFigureInfo(id: "yoga_03", name: "Shoulderstand Pose", isSecret: false, imageURL: yoga + "img_yoga_03.png"),
            SmiskiFigureInfo(id: "yoga_04", name: "Triangle Pose",      isSecret: false, imageURL: yoga + "img_yoga_04.png"),
            SmiskiFigureInfo(id: "yoga_05", name: "Tree Pose",          isSecret: false, imageURL: yoga + "img_yoga_05.png"),
            SmiskiFigureInfo(id: "yoga_06", name: "Ship Pose",          isSecret: false, imageURL: yoga + "img_yoga_06.png"),
            SmiskiFigureInfo(id: "yoga_s",  name: "Twin Hearts ✦",      isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "cheer", name: "Cheer Series", emoji: "📣", figures: [
            SmiskiFigureInfo(id: "cheer_01", name: "Marching",          isSecret: false, imageURL: cheer + "img_cheer_01.png"),
            SmiskiFigureInfo(id: "cheer_02", name: "On Drums",          isSecret: false, imageURL: cheer + "img_cheer_02.png"),
            SmiskiFigureInfo(id: "cheer_03", name: "On Your Side",      isSecret: false, imageURL: cheer + "img_cheer_03.png"),
            SmiskiFigureInfo(id: "cheer_04", name: "Dancing",           isSecret: false, imageURL: cheer + "img_cheer_04.png"),
            SmiskiFigureInfo(id: "cheer_05", name: "Little Cheerleading",isSecret: false, imageURL: cheer + "img_cheer_05.png"),
            SmiskiFigureInfo(id: "cheer_06", name: "Cheering",          isSecret: false, imageURL: cheer + "img_cheer_06.png"),
            SmiskiFigureInfo(id: "cheer_s",  name: "Trophy Angel ✦",    isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "museum", name: "Museum Series", emoji: "🎨", figures: [
            SmiskiFigureInfo(id: "museum_01", name: "The Source",       isSecret: false, imageURL: museum + "img_museum_products_01.png"),
            SmiskiFigureInfo(id: "museum_02", name: "Fujin & Raijin",   isSecret: false, imageURL: museum + "img_museum_products_02.png"),
            SmiskiFigureInfo(id: "museum_03", name: "Bacchus",          isSecret: false, imageURL: museum + "img_museum_products_03.png"),
            SmiskiFigureInfo(id: "museum_04", name: "Velazquez",        isSecret: false, imageURL: museum + "img_museum_products_04.png"),
            SmiskiFigureInfo(id: "museum_05", name: "Dali",             isSecret: false, imageURL: museum + "img_museum_products_05.png"),
            SmiskiFigureInfo(id: "museum_06", name: "Pearl Earring",    isSecret: false, imageURL: museum + "img_museum_products_06.png"),
            SmiskiFigureInfo(id: "museum_s",  name: "King Tut ✦",       isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "work", name: "@Work Series", emoji: "💼", figures: [
            SmiskiFigureInfo(id: "work_01", name: "Approving",          isSecret: false, imageURL: work + "img_work_products_01.png"),
            SmiskiFigureInfo(id: "work_02", name: "Researching",        isSecret: false, imageURL: work + "img_work_products_02.png"),
            SmiskiFigureInfo(id: "work_03", name: "Presenting",         isSecret: false, imageURL: work + "img_work_products_03.png"),
            SmiskiFigureInfo(id: "work_04", name: "Good Idea",          isSecret: false, imageURL: work + "img_work_products_04.png"),
            SmiskiFigureInfo(id: "work_05", name: "On the Road",        isSecret: false, imageURL: work + "img_work_products_05.png"),
            SmiskiFigureInfo(id: "work_06", name: "Group Think",        isSecret: false, imageURL: work + "img_work_products_06.png"),
            SmiskiFigureInfo(id: "work_s",  name: "Lucky Cat ✦",        isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "dressing", name: "Dressing Series", emoji: "👗", figures: [
            SmiskiFigureInfo(id: "dressing_01", name: "Underpants",     isSecret: false, imageURL: dressing + "img_underpants_2.png"),
            SmiskiFigureInfo(id: "dressing_02", name: "Struggling",     isSecret: false, imageURL: dressing + "img_struggling.png"),
            SmiskiFigureInfo(id: "dressing_03", name: "Loose Pants",    isSecret: false, imageURL: dressing + "img_loose-pants.png"),
            SmiskiFigureInfo(id: "dressing_04", name: "Putting On Socks",isSecret: false, imageURL: dressing + "img_putting-on-socks_2.png"),
            SmiskiFigureInfo(id: "dressing_05", name: "Sweater",        isSecret: false, imageURL: dressing + "img_sweater.png"),
            SmiskiFigureInfo(id: "dressing_06", name: "Tight Pants",    isSecret: false, imageURL: dressing + "img_tight-pants.png"),
            SmiskiFigureInfo(id: "dressing_s",  name: "Costume Bunny ✦",isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "exercising", name: "Exercising Series", emoji: "💪", figures: [
            SmiskiFigureInfo(id: "exercising_01", name: "Doing Crunches",isSecret: false, imageURL: exercising + "img_doingcrunches.png"),
            SmiskiFigureInfo(id: "exercising_02", name: "Aerobics",     isSecret: false, imageURL: exercising + "img_aerobics.png"),
            SmiskiFigureInfo(id: "exercising_03", name: "Balance",      isSecret: false, imageURL: exercising + "img_balance.png"),
            SmiskiFigureInfo(id: "exercising_04", name: "Dumbbell",     isSecret: false, imageURL: exercising + "img_dumbbell.png"),
            SmiskiFigureInfo(id: "exercising_05", name: "Hoop",         isSecret: false, imageURL: exercising + "img_hulahoop.png"),
            SmiskiFigureInfo(id: "exercising_06", name: "Stretch",      isSecret: false, imageURL: exercising + "img_stretch.png"),
            SmiskiFigureInfo(id: "exercising_s",  name: "Flexing ✦",    isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "moving", name: "Moving Series", emoji: "📦", figures: [
            SmiskiFigureInfo(id: "moving_01", name: "Carrying Ladder",  isSecret: false, imageURL: moving + "carrying-ladder.png"),
            SmiskiFigureInfo(id: "moving_02", name: "Balancing Boxes",  isSecret: false, imageURL: moving + "balancing-boxes.png"),
            SmiskiFigureInfo(id: "moving_03", name: "Decorating",       isSecret: false, imageURL: moving + "decorating.png"),
            SmiskiFigureInfo(id: "moving_04", name: "Teamwork",         isSecret: false, imageURL: moving + "teamwork.png"),
            SmiskiFigureInfo(id: "moving_05", name: "Green Thumb",      isSecret: false, imageURL: moving + "green-thumb.png"),
            SmiskiFigureInfo(id: "moving_06", name: "Falling Down",     isSecret: false, imageURL: moving + "falling-down.png"),
            SmiskiFigureInfo(id: "moving_s",  name: "Teddy ✦",          isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "hippers", name: "Hippers Series", emoji: "📱", figures: [
            SmiskiFigureInfo(id: "hippers_01", name: "On His Smartphone",isSecret: false, imageURL: hippers + "hippers_01.png"),
            SmiskiFigureInfo(id: "hippers_02", name: "Trying to Climb", isSecret: false, imageURL: hippers + "hippers_02.png"),
            SmiskiFigureInfo(id: "hippers_03", name: "Looking Out",     isSecret: false, imageURL: hippers + "hippers_03.png"),
            SmiskiFigureInfo(id: "hippers_04", name: "Sticking",        isSecret: false, imageURL: hippers + "hippers_04.png"),
            SmiskiFigureInfo(id: "hippers_05", name: "Dozing",          isSecret: false, imageURL: hippers + "hippers_05.png"),
            SmiskiFigureInfo(id: "hippers_06", name: "Upside Down",     isSecret: false, imageURL: hippers + "hippers_06.png"),
            SmiskiFigureInfo(id: "hippers_s",  name: "Headphones ✦",    isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "sunday", name: "Sunday Series", emoji: "☀️", figures: [
            SmiskiFigureInfo(id: "sunday_01", name: "Blowing Bubbles",  isSecret: false, imageURL: sunday + "img_product_sunday01.png"),
            SmiskiFigureInfo(id: "sunday_02", name: "Paper Airplane",   isSecret: false, imageURL: sunday + "img_product_sunday02.png"),
            SmiskiFigureInfo(id: "sunday_03", name: "Sunbathing",       isSecret: false, imageURL: sunday + "img_product_sunday03.png"),
            SmiskiFigureInfo(id: "sunday_04", name: "Sing-Along",       isSecret: false, imageURL: sunday + "img_product_sunday04.png"),
            SmiskiFigureInfo(id: "sunday_05", name: "Skateboarding",    isSecret: false, imageURL: sunday + "img_product_sunday05.png"),
            SmiskiFigureInfo(id: "sunday_06", name: "Gardening",        isSecret: false, imageURL: sunday + "img_product_sunday06.png"),
            SmiskiFigureInfo(id: "sunday_s",  name: "Dog Walk ✦",       isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "birthday", name: "Birthday Series", emoji: "🎂", figures: [
            SmiskiFigureInfo(id: "birthday_01", name: "Giving a Bouquet",isSecret: false, imageURL: birthday + "img_birthday01.png"),
            SmiskiFigureInfo(id: "birthday_02", name: "Wrapped Up",     isSecret: false, imageURL: birthday + "img_birthday02.png"),
            SmiskiFigureInfo(id: "birthday_03", name: "Popping Confetti",isSecret: false, imageURL: birthday + "img_birthday03.png"),
            SmiskiFigureInfo(id: "birthday_04", name: "Birthday Message",isSecret: false, imageURL: birthday + "img_birthday04.png"),
            SmiskiFigureInfo(id: "birthday_05", name: "Decorating",     isSecret: false, imageURL: birthday + "img_birthday05.png"),
            SmiskiFigureInfo(id: "birthday_06", name: "Tasting",        isSecret: false, imageURL: birthday + "img_birthday06.png"),
            SmiskiFigureInfo(id: "birthday_s",  name: "Candle ✦",       isSecret: true,  imageURL: nil),
        ]),
        SmiskiSeriesInfo(id: "construction", name: "Construction Series", emoji: "🔧", figures: [
            SmiskiFigureInfo(id: "construction_01", name: "Digging a Hole",   isSecret: false, imageURL: construction + "img_construction_01.png"),
            SmiskiFigureInfo(id: "construction_02", name: "Crushing Rock",    isSecret: false, imageURL: construction + "img_construction_02.png"),
            SmiskiFigureInfo(id: "construction_03", name: "Tightening Bolt",  isSecret: false, imageURL: construction + "img_construction_03.png"),
            SmiskiFigureInfo(id: "construction_04", name: "Measuring",        isSecret: false, imageURL: construction + "img_construction_04.png"),
            SmiskiFigureInfo(id: "construction_05", name: "Directing Traffic", isSecret: false, imageURL: construction + "img_construction_05.png"),
            SmiskiFigureInfo(id: "construction_06", name: "Loosening Bolt",   isSecret: false, imageURL: construction + "img_construction_06.png"),
            SmiskiFigureInfo(id: "construction_s",  name: "Secret Figure ✦",  isSecret: true,  imageURL: nil),
        ]),
    ]
}
