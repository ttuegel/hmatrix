{-# LANGUAGE BangPatterns #-}

-- $ ghc --make -O2 benchmarks.hs


import Numeric.LinearAlgebra
import System.Time
import System.CPUTime
import Text.Printf
import Data.List(foldl1')


time act = do
    t0 <- getCPUTime
    act
    t1 <- getCPUTime
    printf "%.3f s CPU\n" $ (fromIntegral (t1 - t0) / (10^12 :: Double)) :: IO ()

--------------------------------------------------------------------------------

main = sequence_ [bench1,bench2,bench3,bench4,bench5 1000000 3]

w :: Vector Double
w = constant 1 5000000
w2 = 1 * w

bench1 = do
    putStrLn "Sum of a vector with 5M doubles:"
    print$ vectorMax (w+w2) -- evaluate it
    time $ printf "     BLAS: %.2f: " $ sumVB w
    time $ printf "  Haskell: %.2f: " $ sumVH w
    time $ printf "     BLAS: %.2f: " $ sumVB w
    time $ printf "  Haskell: %.2f: " $ sumVH w
    time $ printf "   innerH: %.2f: " $ innerH w w2

sumVB v = constant 1 (dim v) <.> v

sumVH v = go (d - 1) 0
     where
       d = dim v
       go :: Int -> Double -> Double
       go 0 s = s + (v @> 0)
       go !j !s = go (j - 1) (s + (v @> j))

innerH u v = go (d - 1) 0
     where
       d = dim u
       go :: Int -> Double -> Double
       go 0 s = s + (u @> 0) * (v @> 0)
       go !j !s = go (j - 1) (s + (u @> j) * (v @> j))

-- These functions are much faster if the library
-- is configured with -funsafe

--------------------------------------------------------------------------------

bench2 = do
    putStrLn "-------------------------------------------------------"
    putStrLn "Multiplication of 1M different 3x3 matrices:"
--    putStrLn "from [[]]"
--    time $ print $ manymult (10^6) rot'
--    putStrLn "from (3><3) []"
    time $ print $ manymult (10^6) rot
    print $ cos (10^6/2)


rot' :: Double -> Matrix Double
rot' a = matrix [[ c,0,s],
                 [ 0,1,0],
                 [-s,0,c]]
    where c = cos a
          s = sin a
          matrix = fromLists

rot :: Double -> Matrix Double
rot a = (3><3) [ c,0,s
               , 0,1,0
               ,-s,0,c ]
    where c = cos a
          s = sin a

manymult n r = foldl1' (<>) (map r angles)
    where angles = toList $ linspace n (0,1)
          -- angles = map (k*) [0..n']
          -- n' = fromIntegral n - 1
          -- k  = recip n'

--------------------------------------------------------------------------------

bench3 = do
    putStrLn "-------------------------------------------------------"
    putStrLn "foldVector"
    let v = flatten $ ident 500 :: Vector Double
    print $ vectorMax v  -- evaluate it

    putStrLn "sum, dim=5M:"
    -- time $ print $ foldLoop (\k s -> w@>k + s) 0.0 (dim w)
    time $ print $ sumVector w

    putStrLn "sum, dim=0.25M:"
    --time $ print $ foldLoop (\k s -> v@>k + s) 0.0 (dim v)
    time $ print $ sumVector v

    let getPos k s = if k `mod` 500 < 200 && v@>k > 0 then k:s else s
    putStrLn "foldLoop for element selection, dim=0.25M:"
    time $ print $ (`divMod` 500) $ maximum $ foldLoop getPos [] (dim v)

foldLoop f s d = go (d - 1) s
     where
       go 0 s = f (0::Int) s
       go !j !s = go (j - 1) (f j s)

foldVector f s v = foldLoop g s (dim v)
    where g !k !s = f k (v@>) s
          {-# INLINE g #-} -- Thanks Ryan Ingram (http://permalink.gmane.org/gmane.comp.lang.haskell.cafe/46479)

sumVector = foldVector (\k v s -> v k + s) 0.0

-- foldVector is slower if used in two places unless we use the above INLINE
-- this does not happen with foldLoop
--------------------------------------------------------------------------------

bench4 = do
    putStrLn "-------------------------------------------------------"
    putStrLn "1000x1000 inverse"
    let a = ident 1000 :: Matrix Double
    let b = 2*a
    print $ vectorMax $ flatten (a+b) -- evaluate it
    time $ print $ vectorMax $ flatten $ linearSolve a b

--------------------------------------------------------------------------------

op1 a b = a <> trans b

op2 a b = a + trans b

timep = time . print . vectorMax . flatten

bench5 n d = do
    putStrLn "-------------------------------------------------------"
    putStrLn "transpose in multiply"
    let ms = replicate n ((ident d :: Matrix Double))
    let mz = replicate n (diag (constant (0::Double) d))
    timep $ foldl1' (<>) ms
    timep $ foldl1' op1  ms
    putStrLn "-------------------------------------------------------"
    putStrLn "transpose in add"
    timep $ foldl1' (+)  ms
    timep $ foldl1' op2  ms
