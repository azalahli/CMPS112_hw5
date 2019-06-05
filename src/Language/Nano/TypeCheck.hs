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
    x -> L.nub ([x] ++ (freeTVars y))
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
    case (freeTVars t) of
        x:xs -> lookupTVar x sub

-- | Apply substitution to poly-type
instance Substitutable Poly where    
  apply sub s         = error "TBD: poly apply"

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
extendSubst sub a t = error "TBD: extendSubst"
      
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
unifyTVar st a t = error "TBD: unifyTVar"
    
-- | Unify two types;
--   if successful return an updated state, otherwise throw an error
unify :: InferState -> Type -> Type -> InferState
unify st t1 t2 = error "TBD: unify"

--------------------------------------------------------------------------------
-- Problem 3: Type Inference
--------------------------------------------------------------------------------    
  
infer :: InferState -> TypeEnv -> Expr -> (InferState, Type)
infer st _   (EInt _)          = error "TBD: infer EInt"
infer st _   (EBool _)         = error "TBD: infer EBool"
infer st gamma (EVar x)        = error "TBD: infer EVar"
infer st gamma (ELam x body)   = error "TBD: infer ELam"
infer st gamma (EApp e1 e2)    = error "TBD: infer EApp"
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

-- | Generalize type variables inside a type
generalize :: TypeEnv -> Type -> Poly
generalize gamma t = error "TBD: generalize"
    
-- | Instantiate a polymorphic type into a mono-type with fresh type variables
instantiate :: Int -> Poly -> (Int, Type)
instantiate n s = error "TBD: instantiate"
      
-- | Types of built-in operators and functions      
preludeTypes :: TypeEnv
preludeTypes =
  [ ("+",    Mono $ TInt :=> TInt :=> TInt)
  , ("-",    error "TBD: -")
  , ("*",    error "TBD: *")
  , ("/",    error "TBD: /")
  , ("==",   error "TBD: ==")
  , ("!=",   error "TBD: !=")
  , ("<",    error "TBD: <")
  , ("<=",   error "TBD: <=")
  , ("&&",   error "TBD: &&")
  , ("||",   error "TBD: ||")
  , ("if",   error "TBD: if")
  -- lists: 
  , ("[]",   error "TBD: []")
  , (":",    error "TBD: :")
  , ("head", error "TBD: head")
  , ("tail", error "TBD: tail")
  ]
