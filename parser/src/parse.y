/*
** 2001 September 15
**
** The author disclaims copyright to this source code.  In place of
** a legal notice, here is a blessing:
**
**    May you do good and not evil.
**    May you find forgiveness for yourself and forgive others.
**    May you share freely, never taking more than you give.
**
*************************************************************************
** This file contains SQLite's grammar for SQL.  Process this file
** using the lemon parser generator to generate C code that runs
** the parser.  Lemon will also generate a header file containing
** numeric codes for all of the tokens.
*/

// All token codes are small integers with #defines that begin with "TK_"
%token_prefix TK_

// The type of the data attached to each token is Token.  This is also the
// default type for non-terminals.
//
%token_type {Token}
%default_type {Token}

// An extra argument to the constructor for the parser, which is available
// to all actions.
%extra_context {Parse *pParse}

// This code runs whenever there is a syntax error
//
%syntax_error {
  UNUSED_PARAMETER(yymajor);  /* Silence some compiler warnings */
  if( TOKEN.z[0] ){
    sqlite3ErrorMsg(pParse, "near \"%T\": syntax error", &TOKEN);
  }else{
    sqlite3ErrorMsg(pParse, "incomplete input");
  }
}
%stack_overflow {
  sqlite3ErrorMsg(pParse, "parser stack overflow");
}

// The name of the generated procedure that implements the parser
// is as follows:
%name sqlite3Parser

// The following text is included near the beginning of the C source
// code file that implements the parser.
//
%include {
} // end %include

// Input is a single SQL command
input ::= cmdlist.
cmdlist ::= cmdlist ecmd.
cmdlist ::= ecmd.
ecmd ::= SEMI.
ecmd ::= cmdx SEMI.
%ifndef SQLITE_OMIT_EXPLAIN
ecmd ::= explain cmdx.
explain ::= EXPLAIN.              { pParse->explain = 1; }
explain ::= EXPLAIN QUERY PLAN.   { pParse->explain = 2; }
%endif  SQLITE_OMIT_EXPLAIN
cmdx ::= cmd.           { sqlite3FinishCoding(pParse); }

///////////////////// Begin and end transactions. ////////////////////////////
//

cmd ::= BEGIN transtype(Y) trans_opt.  {sqlite3BeginTransaction(pParse, Y);}
trans_opt ::= .
trans_opt ::= TRANSACTION.
trans_opt ::= TRANSACTION nm.
%type transtype {int}
transtype(A) ::= .             {A = TK_DEFERRED;}
transtype(A) ::= DEFERRED(X).  {A = @X; /*A-overwrites-X*/}
transtype(A) ::= IMMEDIATE(X). {A = @X; /*A-overwrites-X*/}
transtype(A) ::= EXCLUSIVE(X). {A = @X; /*A-overwrites-X*/}
cmd ::= COMMIT|END(X) trans_opt.   {sqlite3EndTransaction(pParse,@X);}
cmd ::= ROLLBACK(X) trans_opt.     {sqlite3EndTransaction(pParse,@X);}

savepoint_opt ::= SAVEPOINT.
savepoint_opt ::= .
cmd ::= SAVEPOINT nm(X). {
  sqlite3Savepoint(pParse, SAVEPOINT_BEGIN, &X);
}
cmd ::= RELEASE savepoint_opt nm(X). {
  sqlite3Savepoint(pParse, SAVEPOINT_RELEASE, &X);
}
cmd ::= ROLLBACK trans_opt TO savepoint_opt nm(X). {
  sqlite3Savepoint(pParse, SAVEPOINT_ROLLBACK, &X);
}

///////////////////// The CREATE TABLE statement ////////////////////////////
//
cmd ::= create_table create_table_args.
create_table ::= createkw temp(T) TABLE ifnotexists(E) nm(Y) dbnm(Z). {
   sqlite3StartTable(pParse,&Y,&Z,T,0,0,E);
}
createkw(A) ::= CREATE(A).  {disableLookaside(pParse);}

%type ifnotexists {int}
ifnotexists(A) ::= .              {A = 0;}
ifnotexists(A) ::= IF NOT EXISTS. {A = 1;}
%type temp {int}
%ifndef SQLITE_OMIT_TEMPDB
temp(A) ::= TEMP.  {A = 1;}
%endif  SQLITE_OMIT_TEMPDB
temp(A) ::= .      {A = 0;}
create_table_args ::= LP columnlist conslist_opt(X) RP(E) table_options(F). {
  sqlite3EndTable(pParse,&X,&E,F,0);
}
create_table_args ::= AS select(S). {
  sqlite3EndTable(pParse,0,0,0,S);
  sqlite3SelectDelete(pParse->db, S);
}
%type table_options {int}
table_options(A) ::= .    {A = 0;}
table_options(A) ::= WITHOUT nm(X). {
  if( X.n==5 && sqlite3_strnicmp(X.z,"rowid",5)==0 ){
    A = TF_WithoutRowid | TF_NoVisibleRowid;
  }else{
    A = 0;
    sqlite3ErrorMsg(pParse, "unknown table option: %.*s", X.n, X.z);
  }
}
columnlist ::= columnlist COMMA columnname carglist.
columnlist ::= columnname carglist.
columnname(A) ::= nm(A) typetoken(Y). {sqlite3AddColumn(pParse,&A,&Y);}

// Declare some tokens early in order to influence their values, to 
// improve performance and reduce the executable size.  The goal here is
// to get the "jump" operations in ISNULL through ESCAPE to have numeric
// values that are early enough so that all jump operations are clustered
// at the beginning, but also so that the comparison tokens NE through GE
// are as large as possible so that they are near to FUNCTION, which is a
// token synthesized by addopcodes.tcl.
//
%token ABORT ACTION AFTER ANALYZE ASC ATTACH BEFORE BEGIN BY CASCADE CAST.
%token CONFLICT DATABASE DEFERRED DESC DETACH EACH END EXCLUSIVE EXPLAIN FAIL.
%token OR AND NOT IS MATCH LIKE_KW BETWEEN IN ISNULL NOTNULL NE EQ.
%token GT LE LT GE ESCAPE.

// The following directive causes tokens ABORT, AFTER, ASC, etc. to
// fallback to ID if they will not parse as their original value.
// This obviates the need for the "id" nonterminal.
//
%fallback ID
  ABORT ACTION AFTER ANALYZE ASC ATTACH BEFORE BEGIN BY CASCADE CAST COLUMNKW
  CONFLICT DATABASE DEFERRED DESC DETACH DO
  EACH END EXCLUSIVE EXPLAIN FAIL FOR
  IGNORE IMMEDIATE INITIALLY INSTEAD LIKE_KW MATCH NO PLAN
  QUERY KEY OF OFFSET PRAGMA RAISE RECURSIVE RELEASE REPLACE RESTRICT ROW ROWS
  ROLLBACK SAVEPOINT TEMP TRIGGER VACUUM VIEW VIRTUAL WITH WITHOUT
%ifdef SQLITE_OMIT_COMPOUND_SELECT
  EXCEPT INTERSECT UNION
%endif SQLITE_OMIT_COMPOUND_SELECT
%ifndef SQLITE_OMIT_WINDOWFUNC
  CURRENT FOLLOWING PARTITION PRECEDING RANGE UNBOUNDED
%endif SQLITE_OMIT_WINDOWFUNC
  REINDEX RENAME CTIME_KW IF
  .
%wildcard ANY.

// Define operator precedence early so that this is the first occurrence
// of the operator tokens in the grammer.  Keeping the operators together
// causes them to be assigned integer values that are close together,
// which keeps parser tables smaller.
//
// The token values assigned to these symbols is determined by the order
// in which lemon first sees them.  It must be the case that ISNULL/NOTNULL,
// NE/EQ, GT/LE, and GE/LT are separated by only a single value.  See
// the sqlite3ExprIfFalse() routine for additional information on this
// constraint.
//
%left OR.
%left AND.
%right NOT.
%left IS MATCH LIKE_KW BETWEEN IN ISNULL NOTNULL NE EQ.
%left GT LE LT GE.
%right ESCAPE.
%left BITAND BITOR LSHIFT RSHIFT.
%left PLUS MINUS.
%left STAR SLASH REM.
%left CONCAT.
%left COLLATE.
%right BITNOT.
%nonassoc ON.

// An IDENTIFIER can be a generic identifier, or one of several
// keywords.  Any non-standard keyword can also be an identifier.
//
%token_class id  ID|INDEXED.


// And "ids" is an identifer-or-string.
//
%token_class ids  ID|STRING.

// The name of a column or table can be any of the following:
//
%type nm {Token}
nm(A) ::= id(A).
nm(A) ::= STRING(A).
nm(A) ::= JOIN_KW(A).

// A typetoken is really zero or more tokens that form a type name such
// as can be found after the column name in a CREATE TABLE statement.
// Multiple tokens are concatenated to form the value of the typetoken.
//
%type typetoken {Token}
typetoken(A) ::= .   {A.n = 0; A.z = 0;}
typetoken(A) ::= typename(A).
typetoken(A) ::= typename(A) LP signed RP(Y). {
  A.n = (int)(&Y.z[Y.n] - A.z);
}
typetoken(A) ::= typename(A) LP signed COMMA signed RP(Y). {
  A.n = (int)(&Y.z[Y.n] - A.z);
}
%type typename {Token}
typename(A) ::= ids(A).
typename(A) ::= typename(A) ids(Y). {A.n=Y.n+(int)(Y.z-A.z);}
signed ::= plus_num.
signed ::= minus_num.

// The scanpt non-terminal takes a value which is a pointer to the
// input text just past the last token that has been shifted into
// the parser.  By surrounding some phrase in the grammar with two
// scanpt non-terminals, we can capture the input text for that phrase.
// For example:
//
//      something ::= .... scanpt(A) phrase scanpt(Z).
//
// The text that is parsed as "phrase" is a string starting at A
// and containing (int)(Z-A) characters.  There might be some extra
// whitespace on either end of the text, but that can be removed in
// post-processing, if needed.
//
%type scanpt {const char*}
scanpt(A) ::= . {
  assert( yyLookahead!=YYNOCODE );
  A = yyLookaheadToken.z;
}

// "carglist" is a list of additional constraints that come after the
// column name and column type in a CREATE TABLE statement.
//
carglist ::= carglist ccons.
carglist ::= .
ccons ::= CONSTRAINT nm(X).           {pParse->constraintName = X;}
ccons ::= DEFAULT scanpt(A) term(X) scanpt(Z).
                            {sqlite3AddDefaultValue(pParse,X,A,Z);}
ccons ::= DEFAULT LP(A) expr(X) RP(Z).
                            {sqlite3AddDefaultValue(pParse,X,A.z+1,Z.z);}
ccons ::= DEFAULT PLUS(A) term(X) scanpt(Z).
                            {sqlite3AddDefaultValue(pParse,X,A.z,Z);}
ccons ::= DEFAULT MINUS(A) term(X) scanpt(Z).      {
  Expr *p = sqlite3PExpr(pParse, TK_UMINUS, X, 0);
  sqlite3AddDefaultValue(pParse,p,A.z,Z);
}
ccons ::= DEFAULT scanpt id(X).       {
  Expr *p = tokenExpr(pParse, TK_STRING, X);
  if( p ){
    sqlite3ExprIdToTrueFalse(p);
    testcase( p->op==TK_TRUEFALSE && sqlite3ExprTruthValue(p) );
  }
  sqlite3AddDefaultValue(pParse,p,X.z,X.z+X.n);
}

// In addition to the type name, we also care about the primary key and
// UNIQUE constraints.
//
ccons ::= NULL onconf.
ccons ::= NOT NULL onconf(R).    {sqlite3AddNotNull(pParse, R);}
ccons ::= PRIMARY KEY sortorder(Z) onconf(R) autoinc(I).
                                 {sqlite3AddPrimaryKey(pParse,0,R,I,Z);}
ccons ::= UNIQUE onconf(R).      {sqlite3CreateIndex(pParse,0,0,0,0,R,0,0,0,0,
                                   SQLITE_IDXTYPE_UNIQUE);}
ccons ::= CHECK LP expr(X) RP.   {sqlite3AddCheckConstraint(pParse,X);}
ccons ::= REFERENCES nm(T) eidlist_opt(TA) refargs(R).
                                 {sqlite3CreateForeignKey(pParse,0,&T,TA,R);}
ccons ::= defer_subclause(D).    {sqlite3DeferForeignKey(pParse,D);}
ccons ::= COLLATE ids(C).        {sqlite3AddCollateType(pParse, &C);}

// The optional AUTOINCREMENT keyword
%type autoinc {int}
autoinc(X) ::= .          {X = 0;}
autoinc(X) ::= AUTOINCR.  {X = 1;}

// The next group of rules parses the arguments to a REFERENCES clause
// that determine if the referential integrity checking is deferred or
// or immediate and which determine what action to take if a ref-integ
// check fails.
//
%type refargs {int}
refargs(A) ::= .                  { A = OE_None*0x0101; /* EV: R-19803-45884 */}
refargs(A) ::= refargs(A) refarg(Y). { A = (A & ~Y.mask) | Y.value; }
%type refarg {struct {int value; int mask;}}
refarg(A) ::= MATCH nm.              { A.value = 0;     A.mask = 0x000000; }
refarg(A) ::= ON INSERT refact.      { A.value = 0;     A.mask = 0x000000; }
refarg(A) ::= ON DELETE refact(X).   { A.value = X;     A.mask = 0x0000ff; }
refarg(A) ::= ON UPDATE refact(X).   { A.value = X<<8;  A.mask = 0x00ff00; }
%type refact {int}
refact(A) ::= SET NULL.              { A = OE_SetNull;  /* EV: R-33326-45252 */}
refact(A) ::= SET DEFAULT.           { A = OE_SetDflt;  /* EV: R-33326-45252 */}
refact(A) ::= CASCADE.               { A = OE_Cascade;  /* EV: R-33326-45252 */}
refact(A) ::= RESTRICT.              { A = OE_Restrict; /* EV: R-33326-45252 */}
refact(A) ::= NO ACTION.             { A = OE_None;     /* EV: R-33326-45252 */}
%type defer_subclause {int}
defer_subclause(A) ::= NOT DEFERRABLE init_deferred_pred_opt.     {A = 0;}
defer_subclause(A) ::= DEFERRABLE init_deferred_pred_opt(X).      {A = X;}
%type init_deferred_pred_opt {int}
init_deferred_pred_opt(A) ::= .                       {A = 0;}
init_deferred_pred_opt(A) ::= INITIALLY DEFERRED.     {A = 1;}
init_deferred_pred_opt(A) ::= INITIALLY IMMEDIATE.    {A = 0;}

conslist_opt(A) ::= .                         {A.n = 0; A.z = 0;}
conslist_opt(A) ::= COMMA(A) conslist.
conslist ::= conslist tconscomma tcons.
conslist ::= tcons.
tconscomma ::= COMMA.            {pParse->constraintName.n = 0;}
tconscomma ::= .
tcons ::= CONSTRAINT nm(X).      {pParse->constraintName = X;}
tcons ::= PRIMARY KEY LP sortlist(X) autoinc(I) RP onconf(R).
                                 {sqlite3AddPrimaryKey(pParse,X,R,I,0);}
tcons ::= UNIQUE LP sortlist(X) RP onconf(R).
                                 {sqlite3CreateIndex(pParse,0,0,0,X,R,0,0,0,0,
                                       SQLITE_IDXTYPE_UNIQUE);}
tcons ::= CHECK LP expr(E) RP onconf.
                                 {sqlite3AddCheckConstraint(pParse,E);}
tcons ::= FOREIGN KEY LP eidlist(FA) RP
          REFERENCES nm(T) eidlist_opt(TA) refargs(R) defer_subclause_opt(D). {
    sqlite3CreateForeignKey(pParse, FA, &T, TA, R);
    sqlite3DeferForeignKey(pParse, D);
}
%type defer_subclause_opt {int}
defer_subclause_opt(A) ::= .                    {A = 0;}
defer_subclause_opt(A) ::= defer_subclause(A).

// The following is a non-standard extension that allows us to declare the
// default behavior when there is a constraint conflict.
//
%type onconf {int}
%type orconf {int}
%type resolvetype {int}
onconf(A) ::= .                              {A = OE_Default;}
onconf(A) ::= ON CONFLICT resolvetype(X).    {A = X;}
orconf(A) ::= .                              {A = OE_Default;}
orconf(A) ::= OR resolvetype(X).             {A = X;}
resolvetype(A) ::= raisetype(A).
resolvetype(A) ::= IGNORE.                   {A = OE_Ignore;}
resolvetype(A) ::= REPLACE.                  {A = OE_Replace;}

////////////////////////// The DROP TABLE /////////////////////////////////////
//
cmd ::= DROP TABLE ifexists(E) fullname(X). {
  sqlite3DropTable(pParse, X, 0, E);
}
%type ifexists {int}
ifexists(A) ::= IF EXISTS.   {A = 1;}
ifexists(A) ::= .            {A = 0;}

///////////////////// The CREATE VIEW statement /////////////////////////////
//
%ifndef SQLITE_OMIT_VIEW
cmd ::= createkw(X) temp(T) VIEW ifnotexists(E) nm(Y) dbnm(Z) eidlist_opt(C)
          AS select(S). {
  sqlite3CreateView(pParse, &X, &Y, &Z, C, S, T, E);
}
cmd ::= DROP VIEW ifexists(E) fullname(X). {
  sqlite3DropTable(pParse, X, 1, E);
}
%endif  SQLITE_OMIT_VIEW

//////////////////////// The SELECT statement /////////////////////////////////
//
cmd ::= select(X).  {
  SelectDest dest = {SRT_Output, 0, 0, 0, 0, 0};
  sqlite3Select(pParse, X, &dest);
  sqlite3SelectDelete(pParse->db, X);
}

%type select {Select*}
%type selectnowith {Select*}
%type oneselect {Select*}

%include {
}

%ifndef SQLITE_OMIT_CTE
select(A) ::= WITH wqlist(W) selectnowith(X). {
  Select *p = X;
  if( p ){
    p->pWith = W;
    parserDoubleLinkSelect(pParse, p);
  }else{
    sqlite3WithDelete(pParse->db, W);
  }
  A = p;
}
select(A) ::= WITH RECURSIVE wqlist(W) selectnowith(X). {
  Select *p = X;
  if( p ){
    p->pWith = W;
    parserDoubleLinkSelect(pParse, p);
  }else{
    sqlite3WithDelete(pParse->db, W);
  }
  A = p;
}
%endif /* SQLITE_OMIT_CTE */
select(A) ::= selectnowith(X). {
  Select *p = X;
  if( p ){
    parserDoubleLinkSelect(pParse, p);
  }
  A = p; /*A-overwrites-X*/
}

selectnowith(A) ::= oneselect(A).
%ifndef SQLITE_OMIT_COMPOUND_SELECT
selectnowith(A) ::= selectnowith(A) multiselect_op(Y) oneselect(Z).  {
  Select *pRhs = Z;
  Select *pLhs = A;
  if( pRhs && pRhs->pPrior ){
    SrcList *pFrom;
    Token x;
    x.n = 0;
    parserDoubleLinkSelect(pParse, pRhs);
    pFrom = sqlite3SrcListAppendFromTerm(pParse,0,0,0,&x,pRhs,0,0);
    pRhs = sqlite3SelectNew(pParse,0,pFrom,0,0,0,0,0,0);
  }
  if( pRhs ){
    pRhs->op = (u8)Y;
    pRhs->pPrior = pLhs;
    if( ALWAYS(pLhs) ) pLhs->selFlags &= ~SF_MultiValue;
    pRhs->selFlags &= ~SF_MultiValue;
    if( Y!=TK_ALL ) pParse->hasCompound = 1;
  }else{
    sqlite3SelectDelete(pParse->db, pLhs);
  }
  A = pRhs;
}
%type multiselect_op {int}
multiselect_op(A) ::= UNION(OP).             {A = @OP; /*A-overwrites-OP*/}
multiselect_op(A) ::= UNION ALL.             {A = TK_ALL;}
multiselect_op(A) ::= EXCEPT|INTERSECT(OP).  {A = @OP; /*A-overwrites-OP*/}
%endif SQLITE_OMIT_COMPOUND_SELECT

oneselect(A) ::= SELECT distinct(D) selcollist(W) from(X) where_opt(Y)
                 groupby_opt(P) having_opt(Q)
                 orderby_opt(Z) limit_opt(L). {
  A = sqlite3SelectNew(pParse,W,X,Y,P,Q,Z,D,L);
    }
%ifndef SQLITE_OMIT_WINDOWFUNC
oneselect(A) ::= SELECT distinct(D) selcollist(W) from(X) where_opt(Y)
                 groupby_opt(P) having_opt(Q) window_clause(R)
                 orderby_opt(Z) limit_opt(L). {
  A = sqlite3SelectNew(pParse,W,X,Y,P,Q,Z,D,L);
  if( A ){
    A->pWinDefn = R;
  }else{
    sqlite3WindowListDelete(pParse->db, R);
  }
}
%endif


oneselect(A) ::= values(A).

%type values {Select*}
values(A) ::= VALUES LP nexprlist(X) RP. {
  A = sqlite3SelectNew(pParse,X,0,0,0,0,0,SF_Values,0);
}
values(A) ::= values(A) COMMA LP nexprlist(Y) RP. {
  Select *pRight, *pLeft = A;
  pRight = sqlite3SelectNew(pParse,Y,0,0,0,0,0,SF_Values|SF_MultiValue,0);
  if( ALWAYS(pLeft) ) pLeft->selFlags &= ~SF_MultiValue;
  if( pRight ){
    pRight->op = TK_ALL;
    pRight->pPrior = pLeft;
    A = pRight;
  }else{
    A = pLeft;
  }
}

// The "distinct" nonterminal is true (1) if the DISTINCT keyword is
// present and false (0) if it is not.
//
%type distinct {int}
distinct(A) ::= DISTINCT.   {A = SF_Distinct;}
distinct(A) ::= ALL.        {A = SF_All;}
distinct(A) ::= .           {A = 0;}

// selcollist is a list of expressions that are to become the return
// values of the SELECT statement.  The "*" in statements like
// "SELECT * FROM ..." is encoded as a special expression with an
// opcode of TK_ASTERISK.
//
%type selcollist {ExprList*}
%type sclp {ExprList*}
sclp(A) ::= selcollist(A) COMMA.
sclp(A) ::= .                                {A = 0;}
selcollist(A) ::= sclp(A) scanpt(B) expr(X) scanpt(Z) as(Y).     {
   A = sqlite3ExprListAppend(pParse, A, X);
   if( Y.n>0 ) sqlite3ExprListSetName(pParse, A, &Y, 1);
   sqlite3ExprListSetSpan(pParse,A,B,Z);
}
selcollist(A) ::= sclp(A) scanpt STAR. {
  Expr *p = sqlite3Expr(pParse->db, TK_ASTERISK, 0);
  A = sqlite3ExprListAppend(pParse, A, p);
}
selcollist(A) ::= sclp(A) scanpt nm(X) DOT STAR. {
  Expr *pRight = sqlite3PExpr(pParse, TK_ASTERISK, 0, 0);
  Expr *pLeft = sqlite3ExprAlloc(pParse->db, TK_ID, &X, 1);
  Expr *pDot = sqlite3PExpr(pParse, TK_DOT, pLeft, pRight);
  A = sqlite3ExprListAppend(pParse,A, pDot);
}

// An option "AS <id>" phrase that can follow one of the expressions that
// define the result set, or one of the tables in the FROM clause.
//
%type as {Token}
as(X) ::= AS nm(Y).    {X = Y;}
as(X) ::= ids(X).
as(X) ::= .            {X.n = 0; X.z = 0;}


%type seltablist {SrcList*}
%type stl_prefix {SrcList*}
%type from {SrcList*}

// A complete FROM clause.
//
from(A) ::= .                {A = sqlite3DbMallocZero(pParse->db, sizeof(*A));}
from(A) ::= FROM seltablist(X). {
  A = X;
  sqlite3SrcListShiftJoinType(A);
}

// "seltablist" is a "Select Table List" - the content of the FROM clause
// in a SELECT statement.  "stl_prefix" is a prefix of this list.
//
stl_prefix(A) ::= seltablist(A) joinop(Y).    {
   if( ALWAYS(A && A->nSrc>0) ) A->a[A->nSrc-1].fg.jointype = (u8)Y;
}
stl_prefix(A) ::= .                           {A = 0;}
seltablist(A) ::= stl_prefix(A) nm(Y) dbnm(D) as(Z) indexed_opt(I)
                  on_opt(N) using_opt(U). {
  A = sqlite3SrcListAppendFromTerm(pParse,A,&Y,&D,&Z,0,N,U);
  sqlite3SrcListIndexedBy(pParse, A, &I);
}
seltablist(A) ::= stl_prefix(A) nm(Y) dbnm(D) LP exprlist(E) RP as(Z)
                  on_opt(N) using_opt(U). {
  A = sqlite3SrcListAppendFromTerm(pParse,A,&Y,&D,&Z,0,N,U);
  sqlite3SrcListFuncArgs(pParse, A, E);
}
%ifndef SQLITE_OMIT_SUBQUERY
  seltablist(A) ::= stl_prefix(A) LP select(S) RP
                    as(Z) on_opt(N) using_opt(U). {
    A = sqlite3SrcListAppendFromTerm(pParse,A,0,0,&Z,S,N,U);
  }
  seltablist(A) ::= stl_prefix(A) LP seltablist(F) RP
                    as(Z) on_opt(N) using_opt(U). {
    if( A==0 && Z.n==0 && N==0 && U==0 ){
      A = F;
    }else if( F->nSrc==1 ){
      A = sqlite3SrcListAppendFromTerm(pParse,A,0,0,&Z,0,N,U);
      if( A ){
        struct SrcList_item *pNew = &A->a[A->nSrc-1];
        struct SrcList_item *pOld = F->a;
        pNew->zName = pOld->zName;
        pNew->zDatabase = pOld->zDatabase;
        pNew->pSelect = pOld->pSelect;
        pOld->zName = pOld->zDatabase = 0;
        pOld->pSelect = 0;
      }
      sqlite3SrcListDelete(pParse->db, F);
    }else{
      Select *pSubquery;
      sqlite3SrcListShiftJoinType(F);
      pSubquery = sqlite3SelectNew(pParse,0,F,0,0,0,0,SF_NestedFrom,0);
      A = sqlite3SrcListAppendFromTerm(pParse,A,0,0,&Z,pSubquery,N,U);
    }
  }
%endif  SQLITE_OMIT_SUBQUERY

%type dbnm {Token}
dbnm(A) ::= .          {A.z=0; A.n=0;}
dbnm(A) ::= DOT nm(X). {A = X;}

%type fullname {SrcList*}
fullname(A) ::= nm(X).  {
  A = sqlite3SrcListAppend(pParse->db,0,&X,0);
  if( IN_RENAME_OBJECT && A ) sqlite3RenameTokenMap(pParse, A->a[0].zName, &X);
}
fullname(A) ::= nm(X) DOT nm(Y). {
  A = sqlite3SrcListAppend(pParse->db,0,&X,&Y);
  if( IN_RENAME_OBJECT && A ) sqlite3RenameTokenMap(pParse, A->a[0].zName, &Y);
}

%type xfullname {SrcList*}
xfullname(A) ::= nm(X).
   {A = sqlite3SrcListAppend(pParse->db,0,&X,0); /*A-overwrites-X*/}
xfullname(A) ::= nm(X) DOT nm(Y).
   {A = sqlite3SrcListAppend(pParse->db,0,&X,&Y); /*A-overwrites-X*/}
xfullname(A) ::= nm(X) DOT nm(Y) AS nm(Z).  {
   A = sqlite3SrcListAppend(pParse->db,0,&X,&Y); /*A-overwrites-X*/
   if( A ) A->a[0].zAlias = sqlite3NameFromToken(pParse->db, &Z);
}
xfullname(A) ::= nm(X) AS nm(Z). {
   A = sqlite3SrcListAppend(pParse->db,0,&X,0); /*A-overwrites-X*/
   if( A ) A->a[0].zAlias = sqlite3NameFromToken(pParse->db, &Z);
}

%type joinop {int}
joinop(X) ::= COMMA|JOIN.              { X = JT_INNER; }
joinop(X) ::= JOIN_KW(A) JOIN.
                  {X = sqlite3JoinType(pParse,&A,0,0);  /*X-overwrites-A*/}
joinop(X) ::= JOIN_KW(A) nm(B) JOIN.
                  {X = sqlite3JoinType(pParse,&A,&B,0); /*X-overwrites-A*/}
joinop(X) ::= JOIN_KW(A) nm(B) nm(C) JOIN.
                  {X = sqlite3JoinType(pParse,&A,&B,&C);/*X-overwrites-A*/}

// There is a parsing abiguity in an upsert statement that uses a
// SELECT on the RHS of a the INSERT:
//
//      INSERT INTO tab SELECT * FROM aaa JOIN bbb ON CONFLICT ...
//                                        here ----^^
//
// When the ON token is encountered, the parser does not know if it is
// the beginning of an ON CONFLICT clause, or the beginning of an ON
// clause associated with the JOIN.  The conflict is resolved in favor
// of the JOIN.  If an ON CONFLICT clause is intended, insert a dummy
// WHERE clause in between, like this:
//
//      INSERT INTO tab SELECT * FROM aaa JOIN bbb WHERE true ON CONFLICT ...
//
// The [AND] and [OR] precedence marks in the rules for on_opt cause the
// ON in this context to always be interpreted as belonging to the JOIN.
//
%type on_opt {Expr*}
on_opt(N) ::= ON expr(E).  {N = E;}
on_opt(N) ::= .     [OR]   {N = 0;}

// Note that this block abuses the Token type just a little. If there is
// no "INDEXED BY" clause, the returned token is empty (z==0 && n==0). If
// there is an INDEXED BY clause, then the token is populated as per normal,
// with z pointing to the token data and n containing the number of bytes
// in the token.
//
// If there is a "NOT INDEXED" clause, then (z==0 && n==1), which is 
// normally illegal. The sqlite3SrcListIndexedBy() function 
// recognizes and interprets this as a special case.
//
%type indexed_opt {Token}
indexed_opt(A) ::= .                 {A.z=0; A.n=0;}
indexed_opt(A) ::= INDEXED BY nm(X). {A = X;}
indexed_opt(A) ::= NOT INDEXED.      {A.z=0; A.n=1;}

%type using_opt {IdList*}
using_opt(U) ::= USING LP idlist(L) RP.  {U = L;}
using_opt(U) ::= .                        {U = 0;}


%type orderby_opt {ExprList*}

// the sortlist non-terminal stores a list of expression where each
// expression is optionally followed by ASC or DESC to indicate the
// sort order.
//
%type sortlist {ExprList*}

orderby_opt(A) ::= .                          {A = 0;}
orderby_opt(A) ::= ORDER BY sortlist(X).      {A = X;}
sortlist(A) ::= sortlist(A) COMMA expr(Y) sortorder(Z). {
  A = sqlite3ExprListAppend(pParse,A,Y);
  sqlite3ExprListSetSortOrder(A,Z);
}
sortlist(A) ::= expr(Y) sortorder(Z). {
  A = sqlite3ExprListAppend(pParse,0,Y); /*A-overwrites-Y*/
  sqlite3ExprListSetSortOrder(A,Z);
}

%type sortorder {int}

sortorder(A) ::= ASC.           {A = SQLITE_SO_ASC;}
sortorder(A) ::= DESC.          {A = SQLITE_SO_DESC;}
sortorder(A) ::= .              {A = SQLITE_SO_UNDEFINED;}

%type groupby_opt {ExprList*}
groupby_opt(A) ::= .                      {A = 0;}
groupby_opt(A) ::= GROUP BY nexprlist(X). {A = X;}

%type having_opt {Expr*}
having_opt(A) ::= .                {A = 0;}
having_opt(A) ::= HAVING expr(X).  {A = X;}

%type limit_opt {Expr*}

// The destructor for limit_opt will never fire in the current grammar.
// The limit_opt non-terminal only occurs at the end of a single production
// rule for SELECT statements.  As soon as the rule that create the 
// limit_opt non-terminal reduces, the SELECT statement rule will also
// reduce.  So there is never a limit_opt non-terminal on the stack 
// except as a transient.  So there is never anything to destroy.
//
//%destructor limit_opt {sqlite3ExprDelete(pParse->db, $$);}
limit_opt(A) ::= .       {A = 0;}
limit_opt(A) ::= LIMIT expr(X).
                         {A = sqlite3PExpr(pParse,TK_LIMIT,X,0);}
limit_opt(A) ::= LIMIT expr(X) OFFSET expr(Y). 
                         {A = sqlite3PExpr(pParse,TK_LIMIT,X,Y);}
limit_opt(A) ::= LIMIT expr(X) COMMA expr(Y). 
                         {A = sqlite3PExpr(pParse,TK_LIMIT,Y,X);}

/////////////////////////// The DELETE statement /////////////////////////////
//
%ifdef SQLITE_ENABLE_UPDATE_DELETE_LIMIT
cmd ::= with DELETE FROM xfullname(X) indexed_opt(I) where_opt(W)
        orderby_opt(O) limit_opt(L). {
  sqlite3SrcListIndexedBy(pParse, X, &I);
  sqlite3DeleteFrom(pParse,X,W,O,L);
}
%endif
%ifndef SQLITE_ENABLE_UPDATE_DELETE_LIMIT
cmd ::= with DELETE FROM xfullname(X) indexed_opt(I) where_opt(W). {
  sqlite3SrcListIndexedBy(pParse, X, &I);
  sqlite3DeleteFrom(pParse,X,W,0,0);
}
%endif

%type where_opt {Expr*}

where_opt(A) ::= .                    {A = 0;}
where_opt(A) ::= WHERE expr(X).       {A = X;}

////////////////////////// The UPDATE command ////////////////////////////////
//
%ifdef SQLITE_ENABLE_UPDATE_DELETE_LIMIT
cmd ::= with UPDATE orconf(R) xfullname(X) indexed_opt(I) SET setlist(Y)
        where_opt(W) orderby_opt(O) limit_opt(L).  {
  sqlite3SrcListIndexedBy(pParse, X, &I);
  sqlite3ExprListCheckLength(pParse,Y,"set list"); 
  sqlite3Update(pParse,X,Y,W,R,O,L,0);
}
%endif
%ifndef SQLITE_ENABLE_UPDATE_DELETE_LIMIT
cmd ::= with UPDATE orconf(R) xfullname(X) indexed_opt(I) SET setlist(Y)
        where_opt(W).  {
  sqlite3SrcListIndexedBy(pParse, X, &I);
  sqlite3ExprListCheckLength(pParse,Y,"set list"); 
  sqlite3Update(pParse,X,Y,W,R,0,0,0);
}
%endif

%type setlist {ExprList*}

setlist(A) ::= setlist(A) COMMA nm(X) EQ expr(Y). {
  A = sqlite3ExprListAppend(pParse, A, Y);
  sqlite3ExprListSetName(pParse, A, &X, 1);
}
setlist(A) ::= setlist(A) COMMA LP idlist(X) RP EQ expr(Y). {
  A = sqlite3ExprListAppendVector(pParse, A, X, Y);
}
setlist(A) ::= nm(X) EQ expr(Y). {
  A = sqlite3ExprListAppend(pParse, 0, Y);
  sqlite3ExprListSetName(pParse, A, &X, 1);
}
setlist(A) ::= LP idlist(X) RP EQ expr(Y). {
  A = sqlite3ExprListAppendVector(pParse, 0, X, Y);
}

////////////////////////// The INSERT command /////////////////////////////////
//
cmd ::= with insert_cmd(R) INTO xfullname(X) idlist_opt(F) select(S)
        upsert(U). {
  sqlite3Insert(pParse, X, S, F, R, U);
}
cmd ::= with insert_cmd(R) INTO xfullname(X) idlist_opt(F) DEFAULT VALUES.
{
  sqlite3Insert(pParse, X, 0, F, R, 0);
}

%type upsert {Upsert*}

// Because upsert only occurs at the tip end of the INSERT rule for cmd,
// there is never a case where the value of the upsert pointer will not
// be destroyed by the cmd action.  So comment-out the destructor to
// avoid unreachable code.
//%destructor upsert {sqlite3UpsertDelete(pParse->db,$$);}
upsert(A) ::= . { A = 0; }
upsert(A) ::= ON CONFLICT LP sortlist(T) RP where_opt(TW)
              DO UPDATE SET setlist(Z) where_opt(W).
              { A = sqlite3UpsertNew(pParse->db,T,TW,Z,W);}
upsert(A) ::= ON CONFLICT LP sortlist(T) RP where_opt(TW) DO NOTHING.
              { A = sqlite3UpsertNew(pParse->db,T,TW,0,0); }
upsert(A) ::= ON CONFLICT DO NOTHING.
              { A = sqlite3UpsertNew(pParse->db,0,0,0,0); }

%type insert_cmd {int}
insert_cmd(A) ::= INSERT orconf(R).   {A = R;}
insert_cmd(A) ::= REPLACE.            {A = OE_Replace;}

%type idlist_opt {IdList*}
%type idlist {IdList*}

idlist_opt(A) ::= .                       {A = 0;}
idlist_opt(A) ::= LP idlist(X) RP.    {A = X;}
idlist(A) ::= idlist(A) COMMA nm(Y).
    {A = sqlite3IdListAppend(pParse,A,&Y);}
idlist(A) ::= nm(Y).
    {A = sqlite3IdListAppend(pParse,0,&Y); /*A-overwrites-Y*/}

/////////////////////////// Expression Processing /////////////////////////////
//

%type expr {Expr*}
%type term {Expr*}

%include {
}

expr(A) ::= term(A).
expr(A) ::= LP expr(X) RP. {A = X;}
expr(A) ::= id(X).          {A=tokenExpr(pParse,TK_ID,X); /*A-overwrites-X*/}
expr(A) ::= JOIN_KW(X).     {A=tokenExpr(pParse,TK_ID,X); /*A-overwrites-X*/}
expr(A) ::= nm(X) DOT nm(Y). {
  Expr *temp1 = sqlite3ExprAlloc(pParse->db, TK_ID, &X, 1);
  Expr *temp2 = sqlite3ExprAlloc(pParse->db, TK_ID, &Y, 1);
  if( IN_RENAME_OBJECT ){
    sqlite3RenameTokenMap(pParse, (void*)temp2, &Y);
    sqlite3RenameTokenMap(pParse, (void*)temp1, &X);
  }
  A = sqlite3PExpr(pParse, TK_DOT, temp1, temp2);
}
expr(A) ::= nm(X) DOT nm(Y) DOT nm(Z). {
  Expr *temp1 = sqlite3ExprAlloc(pParse->db, TK_ID, &X, 1);
  Expr *temp2 = sqlite3ExprAlloc(pParse->db, TK_ID, &Y, 1);
  Expr *temp3 = sqlite3ExprAlloc(pParse->db, TK_ID, &Z, 1);
  Expr *temp4 = sqlite3PExpr(pParse, TK_DOT, temp2, temp3);
  if( IN_RENAME_OBJECT ){
    sqlite3RenameTokenMap(pParse, (void*)temp3, &Z);
    sqlite3RenameTokenMap(pParse, (void*)temp2, &Y);
  }
  A = sqlite3PExpr(pParse, TK_DOT, temp1, temp4);
}
term(A) ::= NULL|FLOAT|BLOB(X). {A=tokenExpr(pParse,@X,X); /*A-overwrites-X*/}
term(A) ::= STRING(X).          {A=tokenExpr(pParse,@X,X); /*A-overwrites-X*/}
term(A) ::= INTEGER(X). {
  A = sqlite3ExprAlloc(pParse->db, TK_INTEGER, &X, 1);
}
expr(A) ::= VARIABLE(X).     {
  if( !(X.z[0]=='#' && sqlite3Isdigit(X.z[1])) ){
    u32 n = X.n;
    A = tokenExpr(pParse, TK_VARIABLE, X);
    sqlite3ExprAssignVarNumber(pParse, A, n);
  }else{
    /* When doing a nested parse, one can include terms in an expression
    ** that look like this:   #1 #2 ...  These terms refer to registers
    ** in the virtual machine.  #N is the N-th register. */
    Token t = X; /*A-overwrites-X*/
    assert( t.n>=2 );
    if( pParse->nested==0 ){
      sqlite3ErrorMsg(pParse, "near \"%T\": syntax error", &t);
      A = 0;
    }else{
      A = sqlite3PExpr(pParse, TK_REGISTER, 0, 0);
      if( A ) sqlite3GetInt32(&t.z[1], &A->iTable);
    }
  }
}
expr(A) ::= expr(A) COLLATE ids(C). {
  A = sqlite3ExprAddCollateToken(pParse, A, &C, 1);
}
%ifndef SQLITE_OMIT_CAST
expr(A) ::= CAST LP expr(E) AS typetoken(T) RP. {
  A = sqlite3ExprAlloc(pParse->db, TK_CAST, &T, 1);
  sqlite3ExprAttachSubtrees(pParse->db, A, E, 0);
}
%endif  SQLITE_OMIT_CAST


expr(A) ::= id(X) LP distinct(D) exprlist(Y) RP. {
  A = sqlite3ExprFunction(pParse, Y, &X, D);
}
expr(A) ::= id(X) LP STAR RP. {
  A = sqlite3ExprFunction(pParse, 0, &X, 0);
}

%ifndef SQLITE_OMIT_WINDOWFUNC
expr(A) ::= id(X) LP distinct(D) exprlist(Y) RP over_clause(Z). {
  A = sqlite3ExprFunction(pParse, Y, &X, D);
  sqlite3WindowAttach(pParse, A, Z);
}
expr(A) ::= id(X) LP STAR RP over_clause(Z). {
  A = sqlite3ExprFunction(pParse, 0, &X, 0);
  sqlite3WindowAttach(pParse, A, Z);
}
%endif

term(A) ::= CTIME_KW(OP). {
  A = sqlite3ExprFunction(pParse, 0, &OP, 0);
}

expr(A) ::= LP nexprlist(X) COMMA expr(Y) RP. {
  ExprList *pList = sqlite3ExprListAppend(pParse, X, Y);
  A = sqlite3PExpr(pParse, TK_VECTOR, 0, 0);
  if( A ){
    A->x.pList = pList;
  }else{
    sqlite3ExprListDelete(pParse->db, pList);
  }
}

expr(A) ::= expr(A) AND(OP) expr(Y).    {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) OR(OP) expr(Y).     {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) LT|GT|GE|LE(OP) expr(Y).
                                        {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) EQ|NE(OP) expr(Y).  {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) BITAND|BITOR|LSHIFT|RSHIFT(OP) expr(Y).
                                        {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) PLUS|MINUS(OP) expr(Y).
                                        {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) STAR|SLASH|REM(OP) expr(Y).
                                        {A=sqlite3PExpr(pParse,@OP,A,Y);}
expr(A) ::= expr(A) CONCAT(OP) expr(Y). {A=sqlite3PExpr(pParse,@OP,A,Y);}
%type likeop {Token}
likeop(A) ::= LIKE_KW|MATCH(A).
likeop(A) ::= NOT LIKE_KW|MATCH(X). {A=X; A.n|=0x80000000; /*A-overwrite-X*/}
expr(A) ::= expr(A) likeop(OP) expr(Y).  [LIKE_KW]  {
  ExprList *pList;
  int bNot = OP.n & 0x80000000;
  OP.n &= 0x7fffffff;
  pList = sqlite3ExprListAppend(pParse,0, Y);
  pList = sqlite3ExprListAppend(pParse,pList, A);
  A = sqlite3ExprFunction(pParse, pList, &OP, 0);
  if( bNot ) A = sqlite3PExpr(pParse, TK_NOT, A, 0);
  if( A ) A->flags |= EP_InfixFunc;
}
expr(A) ::= expr(A) likeop(OP) expr(Y) ESCAPE expr(E).  [LIKE_KW]  {
  ExprList *pList;
  int bNot = OP.n & 0x80000000;
  OP.n &= 0x7fffffff;
  pList = sqlite3ExprListAppend(pParse,0, Y);
  pList = sqlite3ExprListAppend(pParse,pList, A);
  pList = sqlite3ExprListAppend(pParse,pList, E);
  A = sqlite3ExprFunction(pParse, pList, &OP, 0);
  if( bNot ) A = sqlite3PExpr(pParse, TK_NOT, A, 0);
  if( A ) A->flags |= EP_InfixFunc;
}

expr(A) ::= expr(A) ISNULL|NOTNULL(E).   {A = sqlite3PExpr(pParse,@E,A,0);}
expr(A) ::= expr(A) NOT NULL.    {A = sqlite3PExpr(pParse,TK_NOTNULL,A,0);}

%include {
}

//    expr1 IS expr2
//    expr1 IS NOT expr2
//
// If expr2 is NULL then code as TK_ISNULL or TK_NOTNULL.  If expr2
// is any other expression, code as TK_IS or TK_ISNOT.
// 
expr(A) ::= expr(A) IS expr(Y).     {
  A = sqlite3PExpr(pParse,TK_IS,A,Y);
  binaryToUnaryIfNull(pParse, Y, A, TK_ISNULL);
}
expr(A) ::= expr(A) IS NOT expr(Y). {
  A = sqlite3PExpr(pParse,TK_ISNOT,A,Y);
  binaryToUnaryIfNull(pParse, Y, A, TK_NOTNULL);
}

expr(A) ::= NOT(B) expr(X).  
              {A = sqlite3PExpr(pParse, @B, X, 0);/*A-overwrites-B*/}
expr(A) ::= BITNOT(B) expr(X).
              {A = sqlite3PExpr(pParse, @B, X, 0);/*A-overwrites-B*/}
expr(A) ::= PLUS|MINUS(B) expr(X). [BITNOT] {
  A = sqlite3PExpr(pParse, @B==TK_PLUS ? TK_UPLUS : TK_UMINUS, X, 0);
  /*A-overwrites-B*/
}

%type between_op {int}
between_op(A) ::= BETWEEN.     {A = 0;}
between_op(A) ::= NOT BETWEEN. {A = 1;}
expr(A) ::= expr(A) between_op(N) expr(X) AND expr(Y). [BETWEEN] {
  ExprList *pList = sqlite3ExprListAppend(pParse,0, X);
  pList = sqlite3ExprListAppend(pParse,pList, Y);
  A = sqlite3PExpr(pParse, TK_BETWEEN, A, 0);
  if( A ){
    A->x.pList = pList;
  }else{
    sqlite3ExprListDelete(pParse->db, pList);
  } 
  if( N ) A = sqlite3PExpr(pParse, TK_NOT, A, 0);
}
%ifndef SQLITE_OMIT_SUBQUERY
  %type in_op {int}
  in_op(A) ::= IN.      {A = 0;}
  in_op(A) ::= NOT IN.  {A = 1;}
  expr(A) ::= expr(A) in_op(N) LP exprlist(Y) RP. [IN] {
    if( Y==0 ){
      /* Expressions of the form
      **
      **      expr1 IN ()
      **      expr1 NOT IN ()
      **
      ** simplify to constants 0 (false) and 1 (true), respectively,
      ** regardless of the value of expr1.
      */
      sqlite3ExprDelete(pParse->db, A);
      A = sqlite3ExprAlloc(pParse->db, TK_INTEGER,&sqlite3IntTokens[N],1);
    }else if( Y->nExpr==1 ){
      /* Expressions of the form:
      **
      **      expr1 IN (?1)
      **      expr1 NOT IN (?2)
      **
      ** with exactly one value on the RHS can be simplified to something
      ** like this:
      **
      **      expr1 == ?1
      **      expr1 <> ?2
      **
      ** But, the RHS of the == or <> is marked with the EP_Generic flag
      ** so that it may not contribute to the computation of comparison
      ** affinity or the collating sequence to use for comparison.  Otherwise,
      ** the semantics would be subtly different from IN or NOT IN.
      */
      Expr *pRHS = Y->a[0].pExpr;
      Y->a[0].pExpr = 0;
      sqlite3ExprListDelete(pParse->db, Y);
      /* pRHS cannot be NULL because a malloc error would have been detected
      ** before now and control would have never reached this point */
      if( ALWAYS(pRHS) ){
        pRHS->flags &= ~EP_Collate;
        pRHS->flags |= EP_Generic;
      }
      A = sqlite3PExpr(pParse, N ? TK_NE : TK_EQ, A, pRHS);
    }else{
      A = sqlite3PExpr(pParse, TK_IN, A, 0);
      if( A ){
        A->x.pList = Y;
        sqlite3ExprSetHeightAndFlags(pParse, A);
      }else{
        sqlite3ExprListDelete(pParse->db, Y);
      }
      if( N ) A = sqlite3PExpr(pParse, TK_NOT, A, 0);
    }
  }
  expr(A) ::= LP select(X) RP. {
    A = sqlite3PExpr(pParse, TK_SELECT, 0, 0);
    sqlite3PExprAddSelect(pParse, A, X);
  }
  expr(A) ::= expr(A) in_op(N) LP select(Y) RP.  [IN] {
    A = sqlite3PExpr(pParse, TK_IN, A, 0);
    sqlite3PExprAddSelect(pParse, A, Y);
    if( N ) A = sqlite3PExpr(pParse, TK_NOT, A, 0);
  }
  expr(A) ::= expr(A) in_op(N) nm(Y) dbnm(Z) paren_exprlist(E). [IN] {
    SrcList *pSrc = sqlite3SrcListAppend(pParse->db, 0,&Y,&Z);
    Select *pSelect = sqlite3SelectNew(pParse, 0,pSrc,0,0,0,0,0,0);
    if( E )  sqlite3SrcListFuncArgs(pParse, pSelect ? pSrc : 0, E);
    A = sqlite3PExpr(pParse, TK_IN, A, 0);
    sqlite3PExprAddSelect(pParse, A, pSelect);
    if( N ) A = sqlite3PExpr(pParse, TK_NOT, A, 0);
  }
  expr(A) ::= EXISTS LP select(Y) RP. {
    Expr *p;
    p = A = sqlite3PExpr(pParse, TK_EXISTS, 0, 0);
    sqlite3PExprAddSelect(pParse, p, Y);
  }
%endif SQLITE_OMIT_SUBQUERY

/* CASE expressions */
expr(A) ::= CASE case_operand(X) case_exprlist(Y) case_else(Z) END. {
  A = sqlite3PExpr(pParse, TK_CASE, X, 0);
  if( A ){
    A->x.pList = Z ? sqlite3ExprListAppend(pParse,Y,Z) : Y;
    sqlite3ExprSetHeightAndFlags(pParse, A);
  }else{
    sqlite3ExprListDelete(pParse->db, Y);
    sqlite3ExprDelete(pParse->db, Z);
  }
}
%type case_exprlist {ExprList*}
case_exprlist(A) ::= case_exprlist(A) WHEN expr(Y) THEN expr(Z). {
  A = sqlite3ExprListAppend(pParse,A, Y);
  A = sqlite3ExprListAppend(pParse,A, Z);
}
case_exprlist(A) ::= WHEN expr(Y) THEN expr(Z). {
  A = sqlite3ExprListAppend(pParse,0, Y);
  A = sqlite3ExprListAppend(pParse,A, Z);
}
%type case_else {Expr*}
case_else(A) ::=  ELSE expr(X).         {A = X;}
case_else(A) ::=  .                     {A = 0;} 
%type case_operand {Expr*}
case_operand(A) ::= expr(X).            {A = X; /*A-overwrites-X*/} 
case_operand(A) ::= .                   {A = 0;} 

%type exprlist {ExprList*}
%type nexprlist {ExprList*}

exprlist(A) ::= nexprlist(A).
exprlist(A) ::= .                            {A = 0;}
nexprlist(A) ::= nexprlist(A) COMMA expr(Y).
    {A = sqlite3ExprListAppend(pParse,A,Y);}
nexprlist(A) ::= expr(Y).
    {A = sqlite3ExprListAppend(pParse,0,Y); /*A-overwrites-Y*/}

%ifndef SQLITE_OMIT_SUBQUERY
/* A paren_exprlist is an optional expression list contained inside
** of parenthesis */
%type paren_exprlist {ExprList*}
paren_exprlist(A) ::= .   {A = 0;}
paren_exprlist(A) ::= LP exprlist(X) RP.  {A = X;}
%endif SQLITE_OMIT_SUBQUERY


///////////////////////////// The CREATE INDEX command ///////////////////////
//
cmd ::= createkw(S) uniqueflag(U) INDEX ifnotexists(NE) nm(X) dbnm(D)
        ON nm(Y) LP sortlist(Z) RP where_opt(W). {
  sqlite3CreateIndex(pParse, &X, &D, 
                     sqlite3SrcListAppend(pParse->db,0,&Y,0), Z, U,
                      &S, W, SQLITE_SO_ASC, NE, SQLITE_IDXTYPE_APPDEF);
  if( IN_RENAME_OBJECT && pParse->pNewIndex ){
    sqlite3RenameTokenMap(pParse, pParse->pNewIndex->zName, &Y);
  }
}

%type uniqueflag {int}
uniqueflag(A) ::= UNIQUE.  {A = OE_Abort;}
uniqueflag(A) ::= .        {A = OE_None;}


// The eidlist non-terminal (Expression Id List) generates an ExprList
// from a list of identifiers.  The identifier names are in ExprList.a[].zName.
// This list is stored in an ExprList rather than an IdList so that it
// can be easily sent to sqlite3ColumnsExprList().
//
// eidlist is grouped with CREATE INDEX because it used to be the non-terminal
// used for the arguments to an index.  That is just an historical accident.
//
// IMPORTANT COMPATIBILITY NOTE:  Some prior versions of SQLite accepted
// COLLATE clauses and ASC or DESC keywords on ID lists in inappropriate
// places - places that might have been stored in the sqlite_master schema.
// Those extra features were ignored.  But because they might be in some
// (busted) old databases, we need to continue parsing them when loading
// historical schemas.
//
%type eidlist {ExprList*}
%type eidlist_opt {ExprList*}

%include {
} // end %include

eidlist_opt(A) ::= .                         {A = 0;}
eidlist_opt(A) ::= LP eidlist(X) RP.         {A = X;}
eidlist(A) ::= eidlist(A) COMMA nm(Y) collate(C) sortorder(Z).  {
  A = parserAddExprIdListTerm(pParse, A, &Y, C, Z);
}
eidlist(A) ::= nm(Y) collate(C) sortorder(Z). {
  A = parserAddExprIdListTerm(pParse, 0, &Y, C, Z); /*A-overwrites-Y*/
}

%type collate {int}
collate(C) ::= .              {C = 0;}
collate(C) ::= COLLATE ids.   {C = 1;}


///////////////////////////// The DROP INDEX command /////////////////////////
//
cmd ::= DROP INDEX ifexists(E) fullname(X).   {sqlite3DropIndex(pParse, X, E);}

///////////////////////////// The VACUUM command /////////////////////////////
//
%ifndef SQLITE_OMIT_VACUUM
%ifndef SQLITE_OMIT_ATTACH
cmd ::= VACUUM.                {sqlite3Vacuum(pParse,0);}
cmd ::= VACUUM nm(X).          {sqlite3Vacuum(pParse,&X);}
%endif  SQLITE_OMIT_ATTACH
%endif  SQLITE_OMIT_VACUUM

///////////////////////////// The PRAGMA command /////////////////////////////
//
%ifndef SQLITE_OMIT_PRAGMA
cmd ::= PRAGMA nm(X) dbnm(Z).                {sqlite3Pragma(pParse,&X,&Z,0,0);}
cmd ::= PRAGMA nm(X) dbnm(Z) EQ nmnum(Y).    {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
cmd ::= PRAGMA nm(X) dbnm(Z) LP nmnum(Y) RP. {sqlite3Pragma(pParse,&X,&Z,&Y,0);}
cmd ::= PRAGMA nm(X) dbnm(Z) EQ minus_num(Y). 
                                             {sqlite3Pragma(pParse,&X,&Z,&Y,1);}
cmd ::= PRAGMA nm(X) dbnm(Z) LP minus_num(Y) RP.
                                             {sqlite3Pragma(pParse,&X,&Z,&Y,1);}

nmnum(A) ::= plus_num(A).
nmnum(A) ::= nm(A).
nmnum(A) ::= ON(A).
nmnum(A) ::= DELETE(A).
nmnum(A) ::= DEFAULT(A).
%endif SQLITE_OMIT_PRAGMA
%token_class number INTEGER|FLOAT.
plus_num(A) ::= PLUS number(X).       {A = X;}
plus_num(A) ::= number(A).
minus_num(A) ::= MINUS number(X).     {A = X;}
//////////////////////////// The CREATE TRIGGER command /////////////////////

%ifndef SQLITE_OMIT_TRIGGER

cmd ::= createkw trigger_decl(A) BEGIN trigger_cmd_list(S) END(Z). {
  Token all;
  all.z = A.z;
  all.n = (int)(Z.z - A.z) + Z.n;
  sqlite3FinishTrigger(pParse, S, &all);
}

trigger_decl(A) ::= temp(T) TRIGGER ifnotexists(NOERR) nm(B) dbnm(Z) 
                    trigger_time(C) trigger_event(D)
                    ON fullname(E) foreach_clause when_clause(G). {
  sqlite3BeginTrigger(pParse, &B, &Z, C, D.a, D.b, E, G, T, NOERR);
  A = (Z.n==0?B:Z); /*A-overwrites-T*/
}

%type trigger_time {int}
trigger_time(A) ::= BEFORE|AFTER(X).  { A = @X; /*A-overwrites-X*/ }
trigger_time(A) ::= INSTEAD OF.  { A = TK_INSTEAD;}
trigger_time(A) ::= .            { A = TK_BEFORE; }

%type trigger_event {struct TrigEvent}
trigger_event(A) ::= DELETE|INSERT(X).   {A.a = @X; /*A-overwrites-X*/ A.b = 0;}
trigger_event(A) ::= UPDATE(X).          {A.a = @X; /*A-overwrites-X*/ A.b = 0;}
trigger_event(A) ::= UPDATE OF idlist(X).{A.a = TK_UPDATE; A.b = X;}

foreach_clause ::= .
foreach_clause ::= FOR EACH ROW.

%type when_clause {Expr*}
when_clause(A) ::= .             { A = 0; }
when_clause(A) ::= WHEN expr(X). { A = X; }

%type trigger_cmd_list {TriggerStep*}
trigger_cmd_list(A) ::= trigger_cmd_list(A) trigger_cmd(X) SEMI. {
  assert( A!=0 );
  A->pLast->pNext = X;
  A->pLast = X;
}
trigger_cmd_list(A) ::= trigger_cmd(A) SEMI. { 
  assert( A!=0 );
  A->pLast = A;
}

// Disallow qualified table names on INSERT, UPDATE, and DELETE statements
// within a trigger.  The table to INSERT, UPDATE, or DELETE is always in 
// the same database as the table that the trigger fires on.
//
%type trnm {Token}
trnm(A) ::= nm(A).
trnm(A) ::= nm DOT nm(X). {
  A = X;
  sqlite3ErrorMsg(pParse, 
        "qualified table names are not allowed on INSERT, UPDATE, and DELETE "
        "statements within triggers");
}

// Disallow the INDEX BY and NOT INDEXED clauses on UPDATE and DELETE
// statements within triggers.  We make a specific error message for this
// since it is an exception to the default grammar rules.
//
tridxby ::= .
tridxby ::= INDEXED BY nm. {
  sqlite3ErrorMsg(pParse,
        "the INDEXED BY clause is not allowed on UPDATE or DELETE statements "
        "within triggers");
}
tridxby ::= NOT INDEXED. {
  sqlite3ErrorMsg(pParse,
        "the NOT INDEXED clause is not allowed on UPDATE or DELETE statements "
        "within triggers");
}



%type trigger_cmd {TriggerStep*}
// UPDATE 
trigger_cmd(A) ::=
   UPDATE(B) orconf(R) trnm(X) tridxby SET setlist(Y) where_opt(Z) scanpt(E).  
   {A = sqlite3TriggerUpdateStep(pParse, &X, Y, Z, R, B.z, E);}

// INSERT
trigger_cmd(A) ::= scanpt(B) insert_cmd(R) INTO
                      trnm(X) idlist_opt(F) select(S) upsert(U) scanpt(Z). {
   A = sqlite3TriggerInsertStep(pParse,&X,F,S,R,U,B,Z);/*A-overwrites-R*/
}
// DELETE
trigger_cmd(A) ::= DELETE(B) FROM trnm(X) tridxby where_opt(Y) scanpt(E).
   {A = sqlite3TriggerDeleteStep(pParse, &X, Y, B.z, E);}

// SELECT
trigger_cmd(A) ::= scanpt(B) select(X) scanpt(E).
   {A = sqlite3TriggerSelectStep(pParse->db, X, B, E); /*A-overwrites-X*/}

// The special RAISE expression that may occur in trigger programs
expr(A) ::= RAISE LP IGNORE RP.  {
  A = sqlite3PExpr(pParse, TK_RAISE, 0, 0); 
  if( A ){
    A->affinity = OE_Ignore;
  }
}
expr(A) ::= RAISE LP raisetype(T) COMMA nm(Z) RP.  {
  A = sqlite3ExprAlloc(pParse->db, TK_RAISE, &Z, 1); 
  if( A ) {
    A->affinity = (char)T;
  }
}
%endif  !SQLITE_OMIT_TRIGGER

%type raisetype {int}
raisetype(A) ::= ROLLBACK.  {A = OE_Rollback;}
raisetype(A) ::= ABORT.     {A = OE_Abort;}
raisetype(A) ::= FAIL.      {A = OE_Fail;}


////////////////////////  DROP TRIGGER statement //////////////////////////////
%ifndef SQLITE_OMIT_TRIGGER
cmd ::= DROP TRIGGER ifexists(NOERR) fullname(X). {
  sqlite3DropTrigger(pParse,X,NOERR);
}
%endif  !SQLITE_OMIT_TRIGGER

//////////////////////// ATTACH DATABASE file AS name /////////////////////////
%ifndef SQLITE_OMIT_ATTACH
cmd ::= ATTACH database_kw_opt expr(F) AS expr(D) key_opt(K). {
  sqlite3Attach(pParse, F, D, K);
}
cmd ::= DETACH database_kw_opt expr(D). {
  sqlite3Detach(pParse, D);
}

%type key_opt {Expr*}
key_opt(A) ::= .                     { A = 0; }
key_opt(A) ::= KEY expr(X).          { A = X; }

database_kw_opt ::= DATABASE.
database_kw_opt ::= .
%endif SQLITE_OMIT_ATTACH

////////////////////////// REINDEX collation //////////////////////////////////
%ifndef SQLITE_OMIT_REINDEX
cmd ::= REINDEX.                {sqlite3Reindex(pParse, 0, 0);}
cmd ::= REINDEX nm(X) dbnm(Y).  {sqlite3Reindex(pParse, &X, &Y);}
%endif  SQLITE_OMIT_REINDEX

/////////////////////////////////// ANALYZE ///////////////////////////////////
%ifndef SQLITE_OMIT_ANALYZE
cmd ::= ANALYZE.                {sqlite3Analyze(pParse, 0, 0);}
cmd ::= ANALYZE nm(X) dbnm(Y).  {sqlite3Analyze(pParse, &X, &Y);}
%endif

//////////////////////// ALTER TABLE table ... ////////////////////////////////
%ifndef SQLITE_OMIT_ALTERTABLE
cmd ::= ALTER TABLE fullname(X) RENAME TO nm(Z). {
  sqlite3AlterRenameTable(pParse,X,&Z);
}
cmd ::= ALTER TABLE add_column_fullname
        ADD kwcolumn_opt columnname(Y) carglist. {
  Y.n = (int)(pParse->sLastToken.z-Y.z) + pParse->sLastToken.n;
  sqlite3AlterFinishAddColumn(pParse, &Y);
}
add_column_fullname ::= fullname(X). {
  disableLookaside(pParse);
  sqlite3AlterBeginAddColumn(pParse, X);
}
cmd ::= ALTER TABLE fullname(X) RENAME kwcolumn_opt nm(Y) TO nm(Z). {
  sqlite3AlterRenameColumn(pParse, X, &Y, &Z);
}

kwcolumn_opt ::= .
kwcolumn_opt ::= COLUMNKW.

%endif  SQLITE_OMIT_ALTERTABLE

//////////////////////// CREATE VIRTUAL TABLE ... /////////////////////////////
%ifndef SQLITE_OMIT_VIRTUALTABLE
cmd ::= create_vtab.                       {sqlite3VtabFinishParse(pParse,0);}
cmd ::= create_vtab LP vtabarglist RP(X).  {sqlite3VtabFinishParse(pParse,&X);}
create_vtab ::= createkw VIRTUAL TABLE ifnotexists(E)
                nm(X) dbnm(Y) USING nm(Z). {
    sqlite3VtabBeginParse(pParse, &X, &Y, &Z, E);
}
vtabarglist ::= vtabarg.
vtabarglist ::= vtabarglist COMMA vtabarg.
vtabarg ::= .                       {sqlite3VtabArgInit(pParse);}
vtabarg ::= vtabarg vtabargtoken.
vtabargtoken ::= ANY(X).            {sqlite3VtabArgExtend(pParse,&X);}
vtabargtoken ::= lp anylist RP(X).  {sqlite3VtabArgExtend(pParse,&X);}
lp ::= LP(X).                       {sqlite3VtabArgExtend(pParse,&X);}
anylist ::= .
anylist ::= anylist LP anylist RP.
anylist ::= anylist ANY.
%endif  SQLITE_OMIT_VIRTUALTABLE


//////////////////////// COMMON TABLE EXPRESSIONS ////////////////////////////
%type wqlist {With*}

with ::= .
%ifndef SQLITE_OMIT_CTE
with ::= WITH wqlist(W).              { sqlite3WithPush(pParse, W, 1); }
with ::= WITH RECURSIVE wqlist(W).    { sqlite3WithPush(pParse, W, 1); }

wqlist(A) ::= nm(X) eidlist_opt(Y) AS LP select(Z) RP. {
  A = sqlite3WithAdd(pParse, 0, &X, Y, Z); /*A-overwrites-X*/
}
wqlist(A) ::= wqlist(A) COMMA nm(X) eidlist_opt(Y) AS LP select(Z) RP. {
  A = sqlite3WithAdd(pParse, A, &X, Y, Z);
}
%endif  SQLITE_OMIT_CTE

//////////////////////// WINDOW FUNCTION EXPRESSIONS /////////////////////////
// These must be at the end of this file. Specifically, the rules that
// introduce tokens WINDOW, OVER and FILTER must appear last. This causes
// the integer values assigned to these tokens to be larger than all other
// tokens that may be output by the tokenizer except TK_SPACE and TK_ILLEGAL.
//
%ifndef SQLITE_OMIT_WINDOWFUNC
%type windowdefn_list {Window*}
windowdefn_list(A) ::= windowdefn(Z). { A = Z; }
windowdefn_list(A) ::= windowdefn_list(Y) COMMA windowdefn(Z). {
  assert( Z!=0 );
  Z->pNextWin = Y;
  A = Z;
}

%type windowdefn {Window*}
windowdefn(A) ::= nm(X) AS window(Y). {
  if( ALWAYS(Y) ){
    Y->zName = sqlite3DbStrNDup(pParse->db, X.z, X.n);
  }
  A = Y;
}

%type window {Window*}

%type frame_opt {Window*}

%type part_opt {ExprList*}

%type filter_opt {Expr*}

%type range_or_rows {int}

%type frame_bound {struct FrameBound}
%type frame_bound_s {struct FrameBound}
%type frame_bound_e {struct FrameBound}

window(A) ::= LP part_opt(X) orderby_opt(Y) frame_opt(Z) RP. {
  A = Z;
  if( ALWAYS(A) ){
    A->pPartition = X;
    A->pOrderBy = Y;
  }
}

part_opt(A) ::= PARTITION BY nexprlist(X). { A = X; }
part_opt(A) ::= .                          { A = 0; }

frame_opt(A) ::= .                             {
  A = sqlite3WindowAlloc(pParse, TK_RANGE, TK_UNBOUNDED, 0, TK_CURRENT, 0);
}
frame_opt(A) ::= range_or_rows(X) frame_bound_s(Y). {
  A = sqlite3WindowAlloc(pParse, X, Y.eType, Y.pExpr, TK_CURRENT, 0);
}
frame_opt(A) ::= range_or_rows(X) BETWEEN frame_bound_s(Y) AND frame_bound_e(Z). {
  A = sqlite3WindowAlloc(pParse, X, Y.eType, Y.pExpr, Z.eType, Z.pExpr);
}

range_or_rows(A) ::= RANGE.   { A = TK_RANGE; }
range_or_rows(A) ::= ROWS.    { A = TK_ROWS;  }


frame_bound_s(A) ::= frame_bound(X). { A = X; }
frame_bound_s(A) ::= UNBOUNDED PRECEDING. {A.eType = TK_UNBOUNDED; A.pExpr = 0;}
frame_bound_e(A) ::= frame_bound(X). { A = X; }
frame_bound_e(A) ::= UNBOUNDED FOLLOWING. {A.eType = TK_UNBOUNDED; A.pExpr = 0;}

frame_bound(A) ::= expr(X) PRECEDING.   { A.eType = TK_PRECEDING; A.pExpr = X; }
frame_bound(A) ::= CURRENT ROW.         { A.eType = TK_CURRENT  ; A.pExpr = 0; }
frame_bound(A) ::= expr(X) FOLLOWING.   { A.eType = TK_FOLLOWING; A.pExpr = X; }

%type window_clause {Window*}
window_clause(A) ::= WINDOW windowdefn_list(B). { A = B; }

%type over_clause {Window*}
over_clause(A) ::= filter_opt(W) OVER window(Z). {
  A = Z;
  assert( A!=0 );
  A->pFilter = W;
}
over_clause(A) ::= filter_opt(W) OVER nm(Z). {
  A = (Window*)sqlite3DbMallocZero(pParse->db, sizeof(Window));
  if( A ){
    A->zName = sqlite3DbStrNDup(pParse->db, Z.z, Z.n);
    A->pFilter = W;
  }else{
    sqlite3ExprDelete(pParse->db, W);
  }
}

filter_opt(A) ::= .                            { A = 0; }
filter_opt(A) ::= FILTER LP WHERE expr(X) RP.  { A = X; }
%endif /* SQLITE_OMIT_WINDOWFUNC */
