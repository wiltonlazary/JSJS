open Ast
open Lexing
open Parsing
open Exceptions
open Stringify


(*
1. re-defined function declarations should raise errors
2. unit assignments with non-unit type should raise errors
3. top level vals that are re-defined should raise errors
4. vals can be redefined within the scope of a block
5. vals cannot reference a val defined **after** its declaration
*)

module NameMap = Map.Make(String);;
type typesTable = Ast.primitiveType NameMap.t;;
(* A tuple of locals, globals *)
type typeEnv = typesTable * typesTable;;

let rec type_of_expr (env: typeEnv) = function
  | NumLit(_) -> TNum, env
  | BoolLit(_) -> TBool, env
  | StrLit(_) -> TString, env
  | Binop(e1, op, e2) ->
    let t1, _ = type_of_expr env e1 and t2, _ = type_of_expr env e2 in
    if t1 <> t2 then raise (MismatchedTypes (t1, t2))
    else begin
      match op with
      | Caret -> if t1 = TString then TString, env
        else raise (InvalidOperation(t1, Caret))
      | And | Or -> if t1 = TBool then TBool, env
        else raise (InvalidOperation(t1, op))
      | Add | Sub | Mul
      | Div | Mod -> if t1 = TNum then TNum, env
        else raise (InvalidOperation(t1, op))
      | Lte | Gte | Neq
      | Equals | Lt | Gt -> TBool, env
      | _ -> raise (InvalidOperation(t1, op))
    end
  | Unop(op, e) -> begin
      let t, _ = type_of_expr env e in
      match (op, t) with
      | Not, TBool -> TBool, env
      | Neg, TNum -> TNum, env
      | _, _ -> raise (InvalidOperation(t, op))
    end
  | ListLit(es) -> begin
      let ts = List.map (fun x ->
          let t, _ = type_of_expr env x in t)
          es
      in
      if List.length ts = 0 then TList(TSome), env
      else let list_type = List.fold_left
          (fun acc t -> if acc = t then acc
            else raise (NonUniformTypeContainer(acc, t)))
          (List.hd ts) (List.tl ts)
        in
        TList(list_type), env
    end
  | Block(es) -> begin
      match es with
      | [] -> TSome, env
      | x  :: xs ->
        let t, new_env = List.fold_left
            (fun _ e -> (type_of_expr env e))
            (type_of_expr env x) xs
        in
        t, new_env
    end
  | If(p, e1, e2) -> begin
      let pt, _ = type_of_expr env p in
      if pt <> TBool
      then raise (MismatchedTypes(TBool, pt))
      else let t1, _ = type_of_expr env e1 and t2, _ = type_of_expr env e2 in
      if t1 = t2 then t2, env else raise (MismatchedTypes(t1, t2))
    end
  | MapLit(kvpairs) -> begin
      match kvpairs with
      | [] -> TSome, env
      | (key, value) :: xs ->
        let start_key_type, _ = type_of_expr env key in
        let key_type = List.fold_left (fun acc (k, _) ->
            let t, _ = type_of_expr env k in
            if t = acc then acc else raise (MismatchedTypes(acc, t)))
            start_key_type xs
        in
        let start_value_type, _ = type_of_expr env value in
        let value_type = List.fold_left (fun acc (_, v) ->
            let t, _ = type_of_expr env v in
            if t = acc then acc else raise (MismatchedTypes(acc, t)))
            start_value_type xs
        in
        TMap(key_type, value_type), env
    end
  | Assign(id, t, e) -> begin
      let etype, env = type_of_expr env e in
      let _ = match t with
      | TSome -> etype
      | t -> if t = etype then t else raise (MismatchedTypes(t, etype))
      in
      TUnit, env
    end
  | Val(s) -> begin
      let locals, globals = env in
      if NameMap.mem s locals
      then NameMap.find s locals, env
      else if NameMap.mem s globals
      then NameMap.find s globals, env
      else raise (Undefined(s))
    end 
  | _ -> TNum, env
;;

let type_check (program: Ast.program) =
  List.fold_left
    (fun env expr ->
       try
         let _, env = type_of_expr env expr in env
       with
       | InvalidOperation(t, op) ->
         let st = string_of_type t and sop = string_of_op op in
         raise (TypeError (Printf.sprintf "Type error: Invalid operation %s on type '%s'" sop st))
       | MismatchedTypes(t1, t2) ->
         let st1 = string_of_type t1 and st2 = string_of_type t2 in
         raise (TypeError (Printf.sprintf "Type error: expected value of type '%s', got a value of type '%s' instead" st1 st2))
       | NonUniformTypeContainer(t1, t2) ->
         let st1 = string_of_type t1 and st2 = string_of_type t2 in
         raise (TypeError (Printf.sprintf "Type error: Lists can only contain one type. Expected '%s', got a '%s' instead" st1 st2))
       | Undefined(s) ->
         raise (TypeError (Printf.sprintf "Error: value '%s' was used before it was defined" s)))
    (NameMap.empty, NameMap.empty)
    program
;;