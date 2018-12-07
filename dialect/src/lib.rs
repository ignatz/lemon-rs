#![feature(plugin)]
#![plugin(phf_macros)]

extern crate phf;

mod token;
pub use crate::token::TokenType;

static KEYWORDS: phf::Map<&[u8], TokenType> = phf_map! {
    b"ABORT" => TokenType::TK_ABORT,
    b"ACTION" => TokenType::TK_ACTION,
    b"ADD" => TokenType::TK_ADD,
    b"AFTER" => TokenType::TK_AFTER,
    b"ALL" => TokenType::TK_ALL,
    b"ALTER" => TokenType::TK_ALTER,
    b"ANALYZE" => TokenType::TK_ANALYZE,
    b"AND" => TokenType::TK_AND,
    b"AS" => TokenType::TK_AS,
    b"ASC" => TokenType::TK_ASC,
    b"ATTACH" => TokenType::TK_ATTACH,
    b"AUTOINCREMENT" => TokenType::TK_AUTOINCR,
    b"BEFORE" => TokenType::TK_BEFORE,
    b"BEGIN" => TokenType::TK_BEGIN,
    b"BETWEEN" => TokenType::TK_BETWEEN,
    b"BY" => TokenType::TK_BY,
    b"CASCADE" => TokenType::TK_CASCADE,
    b"CASE" => TokenType::TK_CASE,
    b"CAST" => TokenType::TK_CAST,
    b"CHECK" => TokenType::TK_CHECK,
    b"COLLATE" => TokenType::TK_COLLATE,
    b"COLUMN" => TokenType::TK_COLUMNKW,
    b"COMMIT" => TokenType::TK_COMMIT,
    b"CONFLICT" => TokenType::TK_CONFLICT,
    b"CONSTRAINT" => TokenType::TK_CONSTRAINT,
    b"CREATE" => TokenType::TK_CREATE,
    b"CROSS" => TokenType::TK_JOIN_KW,
    b"CURRENT" => TokenType::TK_CURRENT,
    b"CURRENT_DATE" => TokenType::TK_CTIME_KW,
    b"CURRENT_TIME" => TokenType::TK_CTIME_KW,
    b"CURRENT_TIMESTAMP" => TokenType::TK_CTIME_KW,
    b"DATABASE" => TokenType::TK_DATABASE,
    b"DEFAULT" => TokenType::TK_DEFAULT,
    b"DEFERRABLE" => TokenType::TK_DEFERRABLE,
    b"DEFERRED" => TokenType::TK_DEFERRED,
    b"DELETE" => TokenType::TK_DELETE,
    b"DESC" => TokenType::TK_DESC,
    b"DETACH" => TokenType::TK_DETACH,
    b"DISTINCT" => TokenType::TK_DISTINCT,
    b"DO" => TokenType::TK_DO,
    b"DROP" => TokenType::TK_DROP,
    b"EACH" => TokenType::TK_EACH,
    b"ELSE" => TokenType::TK_ELSE,
    b"END" => TokenType::TK_END,
    b"ESCAPE" => TokenType::TK_ESCAPE,
    b"EXCEPT" => TokenType::TK_EXCEPT,
    b"EXCLUSIVE" => TokenType::TK_EXCLUSIVE,
    b"EXISTS" => TokenType::TK_EXISTS,
    b"EXPLAIN" => TokenType::TK_EXPLAIN,
    b"FAIL" => TokenType::TK_FAIL,
    b"FILTER" => TokenType::TK_FILTER,
    b"FOLLOWING" => TokenType::TK_FOLLOWING,
    b"FOR" => TokenType::TK_FOR,
    b"FOREIGN" => TokenType::TK_FOREIGN,
    b"FROM" => TokenType::TK_FROM,
    b"FULL" => TokenType::TK_JOIN_KW,
    b"GLOB" => TokenType::TK_LIKE_KW,
    b"GROUP" => TokenType::TK_GROUP,
    b"HAVING" => TokenType::TK_HAVING,
    b"IF" => TokenType::TK_IF,
    b"IGNORE" => TokenType::TK_IGNORE,
    b"IMMEDIATE" => TokenType::TK_IMMEDIATE,
    b"IN" => TokenType::TK_IN,
    b"INDEX" => TokenType::TK_INDEX,
    b"INDEXED" => TokenType::TK_INDEXED,
    b"INITIALLY" => TokenType::TK_INITIALLY,
    b"INNER" => TokenType::TK_JOIN_KW,
    b"INSERT" => TokenType::TK_INSERT,
    b"INSTEAD" => TokenType::TK_INSTEAD,
    b"INTERSECT" => TokenType::TK_INTERSECT,
    b"INTO" => TokenType::TK_INTO,
    b"IS" => TokenType::TK_IS,
    b"ISNULL" => TokenType::TK_ISNULL,
    b"JOIN" => TokenType::TK_JOIN,
    b"KEY" => TokenType::TK_KEY,
    b"LEFT" => TokenType::TK_JOIN_KW,
    b"LIKE" => TokenType::TK_LIKE_KW,
    b"LIMIT" => TokenType::TK_LIMIT,
    b"MATCH" => TokenType::TK_MATCH,
    b"NATURAL" => TokenType::TK_JOIN_KW,
    b"NO" => TokenType::TK_NO,
    b"NOT" => TokenType::TK_NOT,
    b"NOTHING" => TokenType::TK_NOTHING,
    b"NOTNULL" => TokenType::TK_NOTNULL,
    b"NULL" => TokenType::TK_NULL,
    b"OF" => TokenType::TK_OF,
    b"OFFSET" => TokenType::TK_OFFSET,
    b"ON" => TokenType::TK_ON,
    b"OR" => TokenType::TK_OR,
    b"ORDER" => TokenType::TK_ORDER,
    b"OUTER" => TokenType::TK_JOIN_KW,
    b"OVER" => TokenType::TK_OVER,
    b"PARTITION" => TokenType::TK_PARTITION,
    b"PLAN" => TokenType::TK_PLAN,
    b"PRAGMA" => TokenType::TK_PRAGMA,
    b"PRECEDING" => TokenType::TK_PRECEDING,
    b"PRIMARY" => TokenType::TK_PRIMARY,
    b"QUERY" => TokenType::TK_QUERY,
    b"RAISE" => TokenType::TK_RAISE,
    b"RANGE" => TokenType::TK_RANGE,
    b"RECURSIVE" => TokenType::TK_RECURSIVE,
    b"REFERENCES" => TokenType::TK_REFERENCES,
    b"REGEXP" => TokenType::TK_LIKE_KW,
    b"REINDEX" => TokenType::TK_REINDEX,
    b"RELEASE" => TokenType::TK_RELEASE,
    b"RENAME" => TokenType::TK_RENAME,
    b"REPLACE" => TokenType::TK_REPLACE,
    b"RESTRICT" => TokenType::TK_RESTRICT,
    b"RIGHT" => TokenType::TK_JOIN_KW,
    b"ROLLBACK" => TokenType::TK_ROLLBACK,
    b"ROW" => TokenType::TK_ROW,
    b"ROWS" => TokenType::TK_ROWS,
    b"SAVEPOINT" => TokenType::TK_SAVEPOINT,
    b"SELECT" => TokenType::TK_SELECT,
    b"SET" => TokenType::TK_SET,
    b"TABLE" => TokenType::TK_TABLE,
    b"TEMP" => TokenType::TK_TEMP,
    b"TEMPORARY" => TokenType::TK_TEMP,
    b"THEN" => TokenType::TK_THEN,
    b"TO" => TokenType::TK_TO,
    b"TRANSACTION" => TokenType::TK_TRANSACTION,
    b"TRIGGER" => TokenType::TK_TRIGGER,
    b"UNBOUNDED" => TokenType::TK_UNBOUNDED,
    b"UNION" => TokenType::TK_UNION,
    b"UNIQUE" => TokenType::TK_UNIQUE,
    b"UPDATE" => TokenType::TK_UPDATE,
    b"USING" => TokenType::TK_USING,
    b"VACUUM" => TokenType::TK_VACUUM,
    b"VALUES" => TokenType::TK_VALUES,
    b"VIEW" => TokenType::TK_VIEW,
    b"VIRTUAL" => TokenType::TK_VIRTUAL,
    b"WHEN" => TokenType::TK_WHEN,
    b"WHERE" => TokenType::TK_WHERE,
    b"WINDOW" => TokenType::TK_WINDOW,
    b"WITH" => TokenType::TK_WITH,
    b"WITHOUT" => TokenType::TK_WITHOUT
};
pub const MAX_KEYWORD_LEN: usize = 17;

pub fn is_keyword(name: &str) -> bool {
    if name.len() < 2 || name.len() > MAX_KEYWORD_LEN || !name.is_ascii() {
        return false;
    }
    if KEYWORDS.contains_key(name.as_bytes()) {
        return true;
    }
    unimplemented!()
}

/// word must be uppercase
pub fn keyword_token(word: &[u8]) -> Option<TokenType> {
    KEYWORDS.get(word).cloned()
}

pub fn is_identifier(name: &str) -> bool {
    if name.is_empty() {
        return false;
    }
    let bytes = name.as_bytes();
    is_identifier_start(bytes[0])
        && (bytes.len() == 1 || bytes[1..].iter().all(|b| is_identifier_continue(*b)))
}

pub fn is_identifier_start(b: u8) -> bool {
    (b >= b'A' && b <= b'Z') || b == b'_' || (b >= b'a' && b <= b'z') || b > b'\x7F'
}

pub fn is_identifier_continue(b: u8) -> bool {
    b == b'$'
        || (b >= b'0' && b <= b'9')
        || (b >= b'A' && b <= b'Z')
        || b == b'_'
        || (b >= b'a' && b <= b'z')
        || b > b'\x7F'
}
