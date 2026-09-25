/// How to interpret the bytes of a station's ICY `StreamTitle`.
///
/// `auto` lets the now-playing parser detect windows-1251 titles that arrive
/// mis-decoded as Latin-1; `utf8` trusts the text as delivered; `cp1251`
/// forces the windows-1251 repair.
enum IcyCharset { auto, utf8, cp1251 }
