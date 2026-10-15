import Foundation

// 日语文案 10/15 (日语 分享卡 物品名断行): Japanese item names on share cards break only between the phrases the
// writers marked with "／", so no line splits a word. Keyed by the name as the catalog spells it; a name not
// listed, or reworded since, keeps the system's breaks.
extension ShareCardView {
    /// The Japanese item names split into the phrases a line may break between.
    static let japanesePhrases: [String: [String]] = Dictionary(
        phrased.map { ($0.replacingOccurrences(of: "／", with: ""), $0.components(separatedBy: "／")) },
        uniquingKeysWith: { first, _ in first }
    )

    private static let phrased = [
        "雲の／クッション",
        "ドット絵／カーデ",
        "刺しゅう／ジャケット",
        "原宿／レインコート",
        "クルーネック／ニット",
        "足もとの／ピンクの花",
        "多肉の鉢",
        "制服風／ブレザー",
        "ミニ／サボテン",
        "ナイト／ライト",
        "クマの毛布",
        "ワーク／サロペット",
        "帆布／エプロン",
        "エナジー缶を／あける",
        "カーディガン",
        "ミニ／サンドバッグ",
        "観葉植物",
        "日なた散歩",
        "星の／ヘアゴム",
        "星のバッジ",
        "ボーダー／ヘッドギア",
        "チェックの／スモック",
        "さくらんぼの／ヘアピン",
        "さくら色／テニスウェア",
        "さくら色の／ヘアバンド",
        "オレンジの／ダンベル",
        "オレンジの／ヘッドバンド",
        "ニット帽",
        "もこもこ／カーデ",
        "水玉／ヘッドギア",
        "波柄アロハ",
        "ラベンダーの／トップ",
        "ファイヤー／パーカー",
        "デニム／ジャケット",
        "ネコ耳／パーカー",
        "ネコ耳／ランプ",
        "お絵かき／スモック",
        "白ジャージ",
        "ショート／トレンチ",
        "ピンクの／ヘアゴム",
        "ピンクの／グローブ",
        "ピンクの／ネコ毛布",
        "ピンクの／テニスバッグ",
        "赤ぶち／メガネ",
        "ジャンパー／スカート",
        "青い／タッチペン",
        "ミントの／ヘアゴム",
        "ミントの／ヘッドバンド",
        "ミントの／ヨガブロック",
        "ミントの／ラケット",
        "思わず／くるっと／一回転",
        "紺の／ブックカバー",
        "リボン／ブラウス",
        "ゲーセンT",
        "立ち上がって／お祝い",
        "ランナーの／ヘッドバンド",
        "トラック／ジャケット",
        "タンク／トップ",
        "ミニ／スピーカー",
        "ピクニック",
        "金のしおり",
        "金の／ダンベル",
        "金の／グローブ",
        "金の／ヨガブロック",
        "金の絵筆",
        "金の／ラケット",
        "金の／えんぴつ",
        "ニット／ベスト",
        "イナズマの／ヘッドギア",
        "ウインド／ブレーカー",
        "雨の日",
        "ネオン／ピンクの／グローブ",
        "水色の／ヘッドバンド",
        "黄色の／スケッチブック",
        "黒金／ブルゾン",
        "スタジャン",
        "スタジャン／＋キャップ",
        "はじめての／ジム",
        "はじめての／5km完走",
    ]

    /// `title` as drawn in `language`: in Japanese, joined so a line breaks only between its marked phrases.
    static func breakable(_ title: String, language: Locale.Language) -> String {
        guard language.languageCode == .japanese, let phrases = japanesePhrases[title] else { return title }
        // U+2060 WORD JOINER keeps each phrase whole; U+200B ZERO WIDTH SPACE allows a break between phrases.
        return phrases.map { $0.map(String.init).joined(separator: "\u{2060}") }.joined(separator: "\u{200B}")
    }
}
