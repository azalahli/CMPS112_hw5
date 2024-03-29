{-# LANGUAGE FlexibleInstances, OverloadedStrings, BangPatterns #-}

module Language.Nano.TypeCheck where

import Language.Nano.Types
import Language.Nano.Parser

import qualified Data.List as L
import           Text.Printf (printf)  
import           Control.Exception (throw)

--------------------------------------------------------------------------------
typeOfFile :: FilePath -> IO Type
typeOfFile f = readFile f >>= typeOfString

typeOfString :: String -> IO Type
typeOfString s = typeOfExpr (parseExpr s)

typeOfExpr :: Expr -> IO Type
typeOfExpr e = do
  let (!st, t) = infer initInferState preludeTypes e
  if (length (stSub st)) < 0 then throw (Error ("count Negative: " ++ show (stCnt st)))
  else return t

--------------------------------------------------------------------------------
-- Problem 1: Warm-up
--------------------------------------------------------------------------------

-- | Things that have free type variables
class HasTVars a where
  freeTVars :: a -> [TVar]

-- | Type variables of a type
instance HasTVars Type where
  freeTVars (TInt)          = []
  freeTVars (TBool)         = []
  freeTVars (TVar x)        = [x]
  freeTVars (t1 :=> t2)     = L.nub ((freeTVars t1) ++ (freeTVars t2))
  --L.delete?
  freeTVars (TList t)       = (freeTVars t)

-- | Free type variables of a poly-type (remove forall-bound vars)
instance HasTVars Poly where
  freeTVars (Mono x)     = case x of
    TInt    -> freeTVars (TInt)
    TBool   -> freeTVars (TBool)
    TVar y  -> freeTVars (TVar y)
    (t1 :=> t2) -> freeTVars ((t1 :=> t2))
    (TList t)   -> (freeTVars t)
  freeTVars (Forall x y)   = case x of
    x -> L.delete x (freeTVars y)
    -- is this supposed to be l.delete x from y?
    _ -> error "error"
  -- this should be mono types?
  --poly is probably supposed to be recursively parsed and appended down to a single mono case?
  --freeTVars (Forall (TVar x) (Poly _) ) = [x]

-- | Free type variables of a type environment
instance HasTVars TypeEnv where
  freeTVars gamma   = concat [freeTVars s | (x, s) <- gamma]  
  
-- | Lookup a variable in the type environment  
lookupVarType :: Id -> TypeEnv -> Poly
lookupVarType x ((y, s) : gamma)
  | x == y    = s
  | otherwise = lookupVarType x gamma
lookupVarType x [] = throw (Error ("unbound variable: " ++ x))

-- | Extend the type environment with a new biding
extendTypeEnv :: Id -> Poly -> TypeEnv -> TypeEnv
extendTypeEnv x s gamma = (x,s) : gamma  

-- | Lookup a type variable in a substitution;
--   if not present, return the variable unchanged
lookupTVar :: TVar -> Subst -> Type
lookupTVar a [] = (TVar a)
lookupTVar a (x:xs) 
    | a == fst(x) = snd(x)
    | (xs) == [] = (TVar a)
    | otherwise = (lookupTVar a xs)

-- | Remove a type variable from a substitution
removeTVar :: TVar -> Subst -> Subst
removeTVar a xs = (L.filter (\x1 -> fst(x1) /= a) (xs))
   -- | error "wewp wewp"
   -- |
   -- |

{-}
    | (xs) == [] = xs
    | a == fst(x) = (L.filter (\x1 -> fst(x1) /= a) (x:xs))
    | otherwise = (removeTVar a (xs ++ [x] ) )
    -}   
-- | Things to which type substitutions can be apply
class Substitutable a where
  apply :: Subst -> a -> a
  
-- | Apply substitution to type
-- [] t = type
instance Substitutable Type where  
  apply sub t         = 
    case t of
        (TInt)    -> TInt
        (TBool)   -> TBool
        (TVar a)  -> (lookupTVar a sub)
        --type type needs something to convert to tvar
        (t1 :=> t2) -> (apply sub t1) :=> (apply sub t2)
        (TList a)   -> TList (apply sub a)
--case T of
    -- List etc.
-- | Apply substitution to poly-type
instance Substitutable Poly where    
    apply sub (Mono a)     = case a of
        TInt -> (Mono TInt)
        TBool-> (Mono TBool)
        (TVar x) -> (Mono (lookupTVar x sub))
        (t1 :=> t2) -> (Mono ((apply sub t1) :=> (apply sub t2)))
        (TList x) -> (Mono (TList (apply sub x)))
    apply sub (Forall x y) = Forall x (apply (removeTVar x sub) y)


-- | Apply substitution to (all poly-types in) another substitution
instance Substitutable Subst where  
  apply sub to = zip keys $ map (apply sub) vals
    where
      (keys, vals) = unzip to
      
-- | Apply substitution to a type environment
instance Substitutable TypeEnv where  
  apply sub gamma = zip keys $ map (apply sub) vals
    where
      (keys, vals) = unzip gamma
      
-- | Extend substitution with a new type assignment
extendSubst :: Subst -> TVar -> Type -> Subst
extendSubst sub a t = (a,t):(apply [(a,t)] sub)
    --if sub == apply [(a,t)] sub
    --then (a,t):sub
    --else apply [(a,t)] sub
      
--------------------------------------------------------------------------------
-- Problem 2: Unification
--------------------------------------------------------------------------------
      
-- | State of the type inference algorithm      
data InferState = InferState { 
    stSub :: Subst -- ^ current substitution
  , stCnt :: Int   -- ^ number of fresh type variables generated so far
} deriving Show

-- | Initial state: empty substitution; 0 type variables
initInferState = InferState [] 0

-- | Fresh type variable number n
freshTV n = TVar $ "a" ++ show n      
    
-- | Extend the current substitution of a state with a new type assignment   
extendState :: InferState -> TVar -> Type -> InferState
extendState (InferState sub n) a t = InferState (extendSubst sub a t) n
        
-- | Unify a type variable with a type; 
--   if successful return an updated state, otherwise throw an error
unifyTVar :: InferState -> TVar -> Type -> InferState
unifyTVar (InferState sub n) a t 
    | (TVar a) == t = (InferState (removeTVar a sub) n)
    -- | (lookupTVar a sub) /= a = error ("type error:"
    | L.elem a (freeTVars t) = error ("type error: cannot unify " ++ (show a) ++ " and " ++ (show t) ++ " (occurs check)" )
    | otherwise = extendState (InferState (removeTVar a sub) n) a t
    
    {-}
    case t of
    TInt -> st
    TBool -> st
    (TVar x) -> extendState st a t
    (t1 :=> t2) -> extendState st a t
    (TList x) -> extendState st a t
    -}
    --if True
    --then extendState st a t
    --else error ("type error: cannot unify" ++ (show a) ++ "and" ++ (show t) ++ "(occurs check)" )
    
-- | Unify two types;
--   if successful return an updated state, otherwise throw an error
unify :: InferState -> Type -> Type -> InferState
unify (InferState sub n) t1 t2 
    | t1 == t2 = (InferState sub n)
unify (InferState sub n) (TVar x) t2 = unifyTVar (InferState (removeTVar x sub) n) x t2
unify (InferState sub n) t2 (TVar x) = unifyTVar (InferState (removeTVar x sub) n) x t2
unify (InferState sub n) (TList x) (TList y) = unify (InferState sub n) x y
unify (InferState sub n) (q1 :=> q2) (q3 :=> q4) = unify (unify (InferState sub n) q1 q3) q2 q4
unify _ n m = error ("type error: cannot unify " ++ (show n) ++ " and " ++ (show m) ++ " (occurs check)" )
    
    -- | otherwise = error ("type error: cannot unify " ++ (show t1) ++ " and " ++ (show t2) ++ " (occurs check)" )
    --if t1 == t2 then (InferState sub n) else
    --error ("type error: cannot unify " ++ (show t1) ++ " and " ++ (show t2) ++ " (occurs check)" )
    -- | t1 == t2 = (InferState sub n)

{-}
    unify (InferState sub n) (TVar a) t2
    | otherwise = unifyTVar (InferState sub n) (TVar a) t2
unify (InferState sub n) t1 (TVar a)
    | otherwise = unifyTVar (InferState sub n) (TVar a) t1
-}
--------------------------------------------------------------------------------
-- Problem 3: Type Inference
--------------------------------------------------------------------------------    
  
infer :: InferState -> TypeEnv -> Expr -> (InferState, Type)
infer st _   (EInt _)          = (st, TInt)
infer st _   (EBool _)         = (st, TBool)
infer (InferState sub n) gamma (EVar x)        = ((InferState sub n), (lookupTVar x sub) )
infer (InferState sub n) gamma (ELam x body)   = ((InferState s1 n ), tX' :=> tBody)
        where
            tEnv' = extendTypeEnv x (Mono tX) gamma
            tX = freshTV n 
            ( (InferState s1 a) , tBody) = (infer (InferState sub (n+1) ) tEnv' body)
            tX' = (apply s1 tX)
            {-
            tEnv' = extendTypeEnv x tX gamma
            tX = freshTV n 
            (sub1, tBody) = infer (InferState sub (n+1) ) tEnv' body
            tX' = apply sub1 tX
            -}
infer st gamma (EApp e1 e2)    = error ">_> abandoned"
    
    
    --do 
    --((InferState s1 n1), w1) <- (infer st gamma e1)
    --((InferState s2 n2), w2) <- (infer st gamma e2)
    --return (TInt)
infer st gamma (ELet x e1 e2)  = error "TBD: infer ELet"
infer st gamma (EBin op e1 e2) = infer st gamma asApp
  where
    asApp = EApp (EApp opVar e1) e2
    opVar = EVar (show op)
infer st gamma (EIf c e1 e2) = infer st gamma asApp
  where
    asApp = EApp (EApp (EApp ifVar c) e1) e2
    ifVar = EVar "if"    
infer st gamma ENil = infer st gamma (EVar "[]")

--type TypeEnv = [(Id, Poly)]
-- | Generalize type variables inside a type
generalize :: TypeEnv -> Type -> Poly
generalize gamma t = error "welp"

--lookupPoly x y = 
            {-
lookupTVar :: TVar -> Subst -> Type
lookupTVar a [] = (TVar a)
lookupTVar a (x:xs) 
| a == fst(x) = snd(x)
| (xs) == [] = (TVar a)
| otherwise = (lookupTVar a xs)
            -}
    
-- | Instantiate a polymorphic type into a mono-type with fresh type variables
instantiate :: Int -> Poly -> (Int, Type)
instantiate n s = error "TBD: instantiate"
      
-- | Types of built-in operators and functions      
preludeTypes :: TypeEnv
preludeTypes =
  [ ("+",    Mono $ TInt :=> TInt :=> TInt)
  , ("-",    Mono $ TInt :=> TInt :=> TInt)
  , ("*",    Mono $ TInt :=> TInt :=> TInt)
  , ("/",    Mono $ TInt :=> TInt :=> TInt)
  , ("==",   Mono $ (TVar "q") :=> (TVar "q") :=> TInt)
  , ("!=",   Mono $ (TVar "q") :=> (TVar "q") :=> TInt)
  , ("<",    Mono $ TBool :=> TBool :=> TBool)
  , ("<=",   Mono $ TBool :=> TBool :=> TBool)
  , ("&&",   Mono $ TBool :=> TBool :=> TBool)
  , ("||",   Mono $ TBool :=> TBool :=> TBool)
  , ("if",   Mono $ TBool :=> (TVar "q") :=> (TVar "q") :=> (TVar "q"))
  -- lists: 
  , ("[]",   error "TBD: []")
  , (":",    error "TBD: :")
  , ("head", error "TBD: head")
  , ("tail", error "TBD: tail")
  ]
