{- Test By Convention: the conventions themselves.
 - Copyright   :  (C)opyright 2009 {mwotton, peteg42} at gmail dot com
 - License     :  BSD3
 -
 - FIXME First cut
 -
 - Idea is to apply each of these tests to each line of a 'TestFile'
 - and collate the resulting 'TestSuite'.
 -}
module Test.TBC.Conventions
    ( Convention
    , conventionalIterator
--     , convention_mainPlannedTestSuite
--     , convention_mainTestGroup
--     , convention_main
    ) where

-------------------------------------------------------------------
-- Dependencies.
-------------------------------------------------------------------

import Control.Monad ( liftM )
import Data.Maybe ( catMaybes )

import Test.TBC.FoldDir ( Iterator, ItResult(..) )
import Test.TBC.TestSuite ( Test(..), Result(..), TestSuite(..) )

-------------------------------------------------------------------

-- | A /convention/ maps a line in a 'TestFile' into a 'Test'.
type Convention = String -> Maybe Test

applyConventions :: [Convention] -> String -> [Test]
applyConventions cs = catMaybes . applyCs . lines
    where applyCs ls = [ c l | l <- ls, c <- cs ]

conventionalIterator :: [Convention] -> Iterator TestSuite
conventionalIterator cs suite f =
    do putStrLn $ "conventionIterator: " ++ f
       ts <- applyConventions cs `liftM` readFile f
       let suite' = TestSuiteGroup { tsFile = f, tsTests = [ (t, TestResultNone) | t <- ts ] }
       return (Continue, TestSuiteNode [suite, suite'])



{-
This logic requires an overhaul of the types:

  - if you define mainPlannedTestSuite :: (Plan Int, IO TestSuiteResult), we assume you need control and we'll run it and merge the TAP with other tests. (also mainTestSuite)
  - elsif you define mainTestGroup :: (Plan Int, IO TestGroupResult), we assume you need control and we'll run it and merge the TAP with other tests.
  - elsif you define main :: IO (), we'll treat it as a single test that's passed if it compiles and runs without an exception (?) -- quick and dirty.
-}
