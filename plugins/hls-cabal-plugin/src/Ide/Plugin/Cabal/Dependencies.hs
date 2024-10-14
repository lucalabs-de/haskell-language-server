{-# LANGUAGE OverloadedStrings #-}

module Ide.Plugin.Cabal.Dependencies (
    DependencyInstance(..),
    DependencyInstances(..),
    parseDeps,
    planJsonPath,
) where

import qualified Distribution.Fields               as Syntax
import qualified Distribution.Parsec.Position      as Syntax

import qualified Data.Text                         as T
import qualified Data.Text.Encoding                as Encoding
import           System.FilePath                   ((<.>), (</>))

import           Data.ByteString                   (ByteString)
import           Ide.Plugin.Cabal.Completion.Types
import           Text.Regex.TDFA                   (AllMatches (getAllMatches),
                                                    AllTextMatches (getAllTextMatches),
                                                    (=~))

planJsonPath :: FilePath
planJsonPath = "dist-newstyle" </> "cache" </> "plan" <.> "json" -- hard coded for now

-- | Parses a Field that may contain dependencies
parseDeps :: Syntax.Field Syntax.Position -> [Positioned PkgName]
parseDeps (Syntax.Field (Syntax.Name _ "build-depends") fls) = concatMap mkPosDeps fls
parseDeps (Syntax.Section _ _ fls) = concatMap parseDeps fls
parseDeps _ = []

-- | Matches valid Cabal dependency names
packageRegex :: T.Text
packageRegex = "[a-zA-Z0-9_-]+" -- not sure if this is correct

-- | Parses a single FieldLine of Cabal dependencies. Returns a list since a single line may
-- contain multiple dependencies.
mkPosDeps :: Syntax.FieldLine Syntax.Position -> [Positioned PkgName]
mkPosDeps (Syntax.FieldLine pos dep) = zipWith
        (\n (o, _) -> Positioned (Syntax.Position (Syntax.positionRow pos) (Syntax.positionCol pos + o + 1)) n)
        (getPackageNames dep)
        (getPackageNameOffsets dep)
    where
        getPackageNames :: ByteString -> [T.Text]
        getPackageNames dep = getAllTextMatches (Encoding.decodeUtf8Lenient dep =~ packageRegex)

        getPackageNameOffsets :: ByteString -> [(Int, Int)]
        getPackageNameOffsets dep = getAllMatches (Encoding.decodeUtf8Lenient dep =~ packageRegex)
