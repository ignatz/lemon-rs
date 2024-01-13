use fallible_iterator::FallibleIterator;

use super::{Error, Parser};
use crate::parser::ast::fmt::ToTokens;
use crate::parser::{
    ast::{Cmd, Name, ParameterInfo, QualifiedName, Stmt},
    ParserError,
};

#[test]
fn count_placeholders() -> Result<(), Error> {
    let mut parser = Parser::new(b"SELECT ? WHERE 1 = ?");
    let ast = parser.next()?.unwrap();
    let mut info = ParameterInfo::default();
    ast.to_tokens(&mut info).unwrap();
    assert_eq!(info.count, 2);
    Ok(())
}

#[test]
fn count_numbered_placeholders() -> Result<(), Error> {
    let mut parser = Parser::new(b"SELECT ?1 WHERE 1 = ?2 AND 0 = ?1");
    let ast = parser.next()?.unwrap();
    let mut info = ParameterInfo::default();
    ast.to_tokens(&mut info).unwrap();
    assert_eq!(info.count, 2);
    Ok(())
}

#[test]
fn count_unused_placeholders() -> Result<(), Error> {
    let mut parser = Parser::new(b"SELECT ?1 WHERE 1 = ?3");
    let ast = parser.next()?.unwrap();
    let mut info = ParameterInfo::default();
    ast.to_tokens(&mut info).unwrap();
    assert_eq!(info.count, 3);
    Ok(())
}

#[test]
fn count_named_placeholders() -> Result<(), Error> {
    let mut parser = Parser::new(b"SELECT :x, :y WHERE 1 = :y");
    let ast = parser.next()?.unwrap();
    let mut info = ParameterInfo::default();
    ast.to_tokens(&mut info).unwrap();
    assert_eq!(info.count, 2);
    assert_eq!(info.names.len(), 2);
    assert!(info.names.contains(":x"));
    assert!(info.names.contains(":y"));
    Ok(())
}

#[test]
fn duplicate_column() {
    let mut parser = Parser::new(b"CREATE TABLE t (x TEXT, x TEXT)");
    let r = parser.next();
    let Error::ParserError(ParserError::Custom(msg), _) = r.unwrap_err() else {
        panic!("unexpected error type")
    };
    assert!(msg.contains("duplicate column name"));
}

#[test]
fn create_table_without_column() {
    let mut parser = Parser::new(b"CREATE TABLE t ()");
    let r = parser.next();
    let Error::ParserError(
        ParserError::SyntaxError {
            token_type: "RP",
            found: None,
        },
        _,
    ) = r.unwrap_err()
    else {
        panic!("unexpected error type")
    };
}

#[test]
fn vtab_args() -> Result<(), Error> {
    let sql = r#"CREATE VIRTUAL TABLE mail USING fts3(
  subject VARCHAR(256) NOT NULL,
  body TEXT CHECK(length(body)<10240)
);"#;
    let mut parser = Parser::new(sql.as_bytes());
    let Cmd::Stmt(Stmt::CreateVirtualTable {
        tbl_name: QualifiedName {
            name: Name(tbl_name),
            ..
        },
        module_name: Name(module_name),
        args: Some(args),
        ..
    }) = parser.next()?.unwrap()
    else {
        panic!("unexpected AST")
    };
    assert_eq!(tbl_name, "mail");
    assert_eq!(module_name, "fts3");
    assert_eq!(args.len(), 2);
    assert_eq!(args[0], "subject VARCHAR(256) NOT NULL");
    assert_eq!(args[1], "body TEXT CHECK(length(body)<10240)");
    Ok(())
}

#[test]
fn only_semicolons_no_statements() {
    let sqls = ["", ";", ";;;"];
    for sql in sqls.iter() {
        let mut parser = Parser::new(sql.as_bytes());
        assert_eq!(parser.next().unwrap(), None);
    }
}

#[test]
fn extra_semicolons_between_statements() {
    let sqls = [
        "SELECT 1; SELECT 2",
        "SELECT 1; SELECT 2;",
        "; SELECT 1; SELECT 2",
        ";; SELECT 1;; SELECT 2;;",
    ];
    for sql in sqls.iter() {
        let mut parser = Parser::new(sql.as_bytes());
        assert!(matches!(
            parser.next().unwrap(),
            Some(Cmd::Stmt(Stmt::Select { .. }))
        ));
        assert!(matches!(
            parser.next().unwrap(),
            Some(Cmd::Stmt(Stmt::Select { .. }))
        ));
        assert_eq!(parser.next().unwrap(), None);
    }
}

#[test]
fn insert_mismatch_count() {
    let mut parser = Parser::new(b"INSERT INTO tbl (a, b) VALUES (1)");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "1 values for 2 columns");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn insert_default_values() {
    let mut parser = Parser::new(b"INSERT INTO tbl (a) DEFAULT VALUES");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "0 values for 1 columns");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn create_view_mismatch_count() {
    let mut parser = Parser::new(b"CREATE VIEW v (c1, c2) AS SELECT 1");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "expected 2 columns for v but got 1");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn create_view_duplicate_column_name() {
    let mut parser = Parser::new(b"CREATE VIEW v (c1, c1) AS SELECT 1, 2");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "duplicate column name: c1");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn create_table_without_rowid_missing_pk() {
    let mut parser = Parser::new(b"CREATE TABLE tbl (c1) WITHOUT ROWID");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "PRIMARY KEY missing on table tbl");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn create_strict_table_missing_datatype() {
    let mut parser = Parser::new(b"CREATE TABLE tbl (c1) STRICT");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "missing datatype for tbl.c1");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn create_strict_table_unknown_datatype() {
    let mut parser = Parser::new(b"CREATE TABLE tbl (c1 BOOL) STRICT");
    let r = parser.next();
    if let Error::ParserError(ParserError::Custom(ref msg), _) = r.unwrap_err() {
        assert_eq!(msg, "unknown datatype for tbl.c1: \"BOOL\"");
    } else {
        panic!("unexpected error type")
    };
}

#[test]
fn create_strict_table_generated_column() {
    let mut parser = Parser::new(
        b"CREATE TABLE IF NOT EXISTS transactions (
      debit REAL,
      credit REAL,
      amount REAL GENERATED ALWAYS AS (ifnull(credit, 0.0) -ifnull(debit, 0.0))
  ) STRICT;
",
    );
    let r = parser.next();
    r.unwrap();
}
