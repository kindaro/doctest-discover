module Main where

import System.Environment
import Control.Applicative 
import Control.Monad
import Data.Maybe (fromMaybe, listToMaybe)
import Data.List (sort, isPrefixOf)
import Runner
import Config
import System.Directory
import System.FilePath

main :: IO ()
main = do
    (_ : _ : dst : args) <- getArgs
    maybeConfiguration <- readConfig (listToMaybe args)
    testDriverFileContents <- buildDriverFileContents maybeConfiguration
    writeFile dst testDriverFileContents

-- | Obtain configuration, given a configuration file.
--
-- >>> readConfig (Just "test/test-config.json")
-- Just (Config {ignore = ..., sourceFolders = ..., doctestOptions = ...})

readConfig :: Maybe FilePath -> IO (Maybe Config)
readConfig x = config <$> configFileContents
  where
    configFileContents :: IO String
    configFileContents = fromMaybe (return "") (readFile <$> x)

-- | Given a configuration, build a driver.

buildDriverFileContents :: Maybe Config -> IO String
buildDriverFileContents x = do
    let sources = fromMaybe ["src"] $ x >>= sourceFolders
    files <- sequence $ map getAbsDirectoryContents sources
    return $ driver (concat files) x

-- | Recursively get absolute directory contents
--
-- >>> :m +Data.List
-- >>> prefix <- getCurrentDirectory
-- >>> map (stripPrefix prefix) <$> getAbsDirectoryContents "test/example"
-- [Just "/test/example/Foo.hs",Just "/test/example/Foo/Bar.hs"]
--
-- >>> map (stripPrefix prefix) <$> getAbsDirectoryContents "test/example-with-dotfiles"
-- [Just "/test/example-with-dotfiles/Baz.hs"]

getAbsDirectoryContents :: FilePath -> IO [FilePath]
getAbsDirectoryContents dir = do
    paths <- filter notDotfile <$> getDirectoryContents dir
    paths' <- forM (filter notDotfile paths) $ \path -> do
        canonicalized <- canonicalizePath $ dir </> path
        isDir <- doesDirectoryExist canonicalized
        if isDir
            then getAbsDirectoryContents canonicalized
            else return [canonicalized]
    return $ sort $ concat paths'
  where notDotfile = not . ("." `isPrefixOf`)
