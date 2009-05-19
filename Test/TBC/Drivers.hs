{- Test By Convention: Drivers.
 - Copyright   :  (C)opyright 2009 {mwotton, peteg42} at gmail dot com
 - License     :  BSD3
 -}
module Test.TBC.Drivers
    ( Driver(..)
    , ghci
    ) where

-------------------------------------------------------------------
-- Dependencies.
-------------------------------------------------------------------

import Control.Concurrent -- ( forkIO )
import Control.Monad ( liftM )

import Data.List ( isInfixOf )

import System.Exit
import System.IO -- ( hClose, hFlush, hGetContents, hPutStr )
import System.Process ( runInteractiveProcess, waitForProcess )

import Debug.Trace

-------------------------------------------------------------------

-- Drivers
data Driver
    = MkDriver
      { hci_send_cmd :: String -> IO [String] -- ^ FIXME exec and return lines of response.
      , hci_load_file :: String -> IO [String] -- ^ FIXME exec and return lines of response.
      , hci_close :: IO ExitCode
      }

----------------------------------------

-- | GHCi driver, slave process.
ghci :: String -- ^ ghci command name
     -> [String] -- ^ flags
     -> IO Driver
ghci cmd flags =
  do putStrLn $ "system $ " ++ cmd ++ " " ++ concat [ ' ' : a | a <- flags ]
     putStrLn $ "----------------------------------------\n"
     (hin, hout, herr, hpid)
         <- runInteractiveProcess cmd flags Nothing Nothing -- FIXME

     -- Configure GHCi a bit FIXME
     hPutStrLn hin ":set prompt \"\""
     hPutStrLn hin "GHC.Handle.hDuplicateTo System.IO.stdout System.IO.stderr"

     -- We don't use GHCi's stderr, get rid of it.
     -- FIXME we maybe have to drain it first.
     hClose herr

     let load_file f =
           do cout <- ghci_sync hin hout (":l " ++ f ++ "\n")
              if not (null cout) && "Ok, modules loaded" `isInfixOf` last cout
                then return []
                else return cout

     return $ MkDriver
                { hci_send_cmd = ghci_sync hin hout
                , hci_load_file = load_file
                , hci_close = trace "hci_close" $ hPutStr hin ":quit\n" >>  hFlush hin >> waitForProcess hpid
                }

ghci_sync :: Handle -> Handle -> String -> IO [String]
ghci_sync hin hout inp =
  do
--      putStrLn $ "--Sync----------------------------------"
--      putStr inp
--      putStrLn $ "----------------------------------------"

     -- FIXME do we really need the separate thread?
     -- Get output + sync
     outMVar <- newEmptyMVar
     forkIO $ hc_sync hout >>= putMVar outMVar

     -- Tests + sync
     hPutStr hin inp
     hPutStr hin hc_sync_print
     hFlush hin

     -- Synchronize
     hc_output <- lint_output `liftM` takeMVar outMVar

--      putStrLn $ ">> Output <<"
--      putStr (unlines hc_output)

     return hc_output
  where
    lint_output :: [[a]] -> [[a]]
    lint_output = reverse . dropWhile null . reverse . dropWhile null

    done :: String
    done = ">>>>done<<<<"

    hc_sync_print :: String
    hc_sync_print = "System.IO.putStrLn \"" ++ done ++ "\"\n"

    -- FIXME EOF, exceptions, etc.
    hc_sync :: Handle -> IO [String]
    hc_sync h = sync
        where
          sync =
              do l <- hGetLine h
--                  putStrLn $ "hc>> " ++ l
                 if done `isInfixOf` l
                   then return []
                   else (l:) `liftM` sync