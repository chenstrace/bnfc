{-
    BNF Converter: C++ Main file
    Copyright (C) 2004  Author:  Markus Forsberg, Michael Pellauer

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
-}

module BNFC.Backend.CPP.NoSTL (makeCppNoStl) where

import BNFC.Utils
import BNFC.CF
import BNFC.Options
import BNFC.Backend.Base
import BNFC.Backend.CPP.Makefile
import BNFC.Backend.CPP.NoSTL.CFtoCPPAbs
import BNFC.Backend.CPP.NoSTL.CFtoFlex
import BNFC.Backend.CPP.NoSTL.CFtoBison
import BNFC.Backend.CPP.NoSTL.CFtoCVisitSkel
import BNFC.Backend.CPP.PrettyPrinter
import Data.Char
import qualified BNFC.Backend.Common.Makefile as Makefile

makeCppNoStl :: SharedOptions -> CF -> MkFiles ()
makeCppNoStl opts cf = do
    let (hfile, cfile) = cf2CPPAbs name cf
    mkfile "Absyn.H" hfile
    mkfile "Absyn.C" cfile
    let (flex, env) = cf2flex Nothing name cf
    mkfile (name ++ ".l") flex
    let bison = cf2Bison name cf env
    mkfile (name ++ ".y") bison
    let header = mkHeaderFile cf (allCats cf) (allEntryPoints cf) env
    mkfile "Parser.H" header
    let (skelH, skelC) = cf2CVisitSkel cf
    mkfile "Skeleton.H" skelH
    mkfile "Skeleton.C" skelC
    let (prinH, prinC) = cf2CPPPrinter False Nothing cf
    mkfile "Printer.H" prinH
    mkfile "Printer.C" prinC
    mkfile "Test.C" (cpptest cf)
    Makefile.mkMakefile opts $ makefile name
  where name = lang opts


cpptest :: CF -> String
cpptest cf =
  unlines
   [
    "/*** Compiler Front-End Test automatically generated by the BNF Converter ***/",
    "/*                                                                          */",
    "/* This test will parse a file, print the abstract syntax tree, and then    */",
    "/* pretty-print the result.                                                 */",
    "/*                                                                          */",
    "/****************************************************************************/",
    "#include <stdio.h>",
    "#include \"Parser.H\"",
    "#include \"Printer.H\"",
    "#include \"Absyn.H\"",
    "",
    "int main(int argc, char ** argv)",
    "{",
    "  FILE *input;",
    "  if (argc > 1) ",
    "  {",
    "    input = fopen(argv[1], \"r\");",
    "    if (!input)",
    "    {",
    "      fprintf(stderr, \"Error opening input file.\\n\");",
    "      exit(1);",
    "    }",
    "  }",
    "  else input = stdin;",
    "  /* The default entry point is used. For other options see Parser.H */",
    "  " ++ def ++ " *parse_tree = p" ++ def ++ "(input);",
    "  if (parse_tree)",
    "  {",
    "    printf(\"\\nParse Succesful!\\n\");",
    "    printf(\"\\n[Abstract Syntax]\\n\");",
    "    ShowAbsyn *s = new ShowAbsyn();",
    "    printf(\"%s\\n\\n\", s->show(parse_tree));",
    "    printf(\"[Linearized Tree]\\n\");",
    "    PrintAbsyn *p = new PrintAbsyn();",
    "    printf(\"%s\\n\\n\", p->print(parse_tree));",
    "    return 0;",
    "  }",
    "  return 1;",
    "}",
    ""
   ]
  where
   def = show (head (allEntryPoints cf))

mkHeaderFile cf cats eps env = unlines
 [
  "#ifndef PARSER_HEADER_FILE",
  "#define PARSER_HEADER_FILE",
  "",
  concatMap mkForwardDec cats,
  "typedef union",
  "{",
  "  int int_;",
  "  char char_;",
  "  double double_;",
  "  char* string_;",
  concatMap mkVar cats ++ "} YYSTYPE;",
  "",
  "#define _ERROR_ 258",
  mkDefines (259 :: Int) env,
  "extern YYSTYPE yylval;",
  concatMap mkFunc eps,
  "",
  "#endif"
 ]
 where
  mkForwardDec s | normCat s == s = "class " ++ identCat s ++ ";\n"
  mkForwardDec _ = ""
  mkVar s | normCat s == s = "  " ++ identCat s ++"*" +++ map toLower (identCat s) ++ "_;\n"
  mkVar _ = ""
  mkDefines n [] = mkString n
  mkDefines n ((_,s):ss) = "#define " ++ s +++ show n ++ "\n" ++ mkDefines (n+1) ss
  mkString n =  if isUsedCat cf catString
   then ("#define _STRING_ " ++ show n ++ "\n") ++ mkChar (n+1)
   else mkChar n
  mkChar n =  if isUsedCat cf catChar
   then ("#define _CHAR_ " ++ show n ++ "\n") ++ mkInteger (n+1)
   else mkInteger n
  mkInteger n =  if isUsedCat cf catInteger
   then ("#define _INTEGER_ " ++ show n ++ "\n") ++ mkDouble (n+1)
   else mkDouble n
  mkDouble n =  if isUsedCat cf catDouble
   then ("#define _DOUBLE_ " ++ show n ++ "\n") ++ mkIdent(n+1)
   else mkIdent n
  mkIdent n =  if isUsedCat cf catIdent
   then "#define _IDENT_ " ++ show n ++ "\n"
   else ""
  mkFunc s | normCat s == s = identCat s ++ "*" +++ "p" ++ identCat s ++ "(FILE *inp);\n"
  mkFunc _ = ""
