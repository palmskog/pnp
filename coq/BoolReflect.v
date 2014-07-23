(** 

%\chapter{Views and Boolean Reflection}
\label{ch:boolrefl}%

*)

(* begin hide *)
Module BoolReflect.
(* end hide *)

(** remove printing ~ *)
(** printing ~ %\textasciitilde% *)
(** printing R $R$ *)
(** printing done %\texttt{\emph{done}}% *)
(** printing congr %\texttt{\emph{congr}}% *)
(** printing of %\texttt{\emph{of}}% *)
(** printing suff %\texttt{\emph{suff}}% *)
(** printing have %\texttt{\emph{have}}% *)
(** printing View %\texttt{\emph{View}}% *)

(** 

In %Chapter~\ref{ch:eqrew}% we have seen how custom rewriting rules
and truth tables can be encoded in Coq using its support for indexed
datatype families, so they offer great support for constructing the
proofs by case analysis and rewriting. In this chapter, we will show
how the custom rewriting machinery can be taken to the whole new level
and be used to facilitate the reasoning about _computable_ properties
and predicates. We will consider a series of insights that lead to the
idea of the _small-scale reflection_, the %\index{small-scale
reflection|textbf}% heart of the SSReflect framework, which blurs the
boundaries between computable predicates defined in the sort [Prop]
(see %Chapter~\ref{ch:logic}%) and Coq's recursive functions returning
a result of type [bool] (in the spirit of the definitions that we have
seen in %Chapter~\ref{ch:funprog}%). That said, in the vast number of
cases these two are just two sides of the same coin and, hence, should
be treated uniformly, serving to facilitate the reasoning in two
different directions: %\index{reflection|see {small-scale
reflection}}%

- expressing quantifications and building the proofs by means of
  _constructive reasoning_ with logical connectives as datatypes
  defined in the sort [Prop];

- employing brute-force computations for quantifier-free goals within
  the Coq framework itself, taken as a programming language, in order
  to reduce the goals to be proved by means of simply _computing_
  them.

We will elaborate more on the differences between predicates stated by
means of [Prop] and [bool] in %Section~\ref{sec:propbool}%. The term
_small-scale reflection_, which gives the name to the whole framework
of SSReflect, emphasizes the two complementary ways of building
proofs: by means of intuitionistic inference (i.e., using the
constructors of datatypes defined in [Prop]) and by means of mere
computation (i.e., with [bool]-returning function). These two ways,
therefore, serve as each other's "reflections" and, moreover, both are
implemented within the same system, without the need to appeal to
Coq's meta-object protocol,%\footnote{In contrast, reflection in Java,
Python or Ruby actually does appeal to the meta-object protocol, e.g.,
\index{meta-object protocol} the structure of the classes, which lies
beyond the formally defined semantics of the language itself and,
hence, allow one to modify the program's behaviour at runtime.}% which
makes this reflection _small_scale_.

Unfortunately, the proper explanation of the implementation of the
reflection mechanism between [Prop] and [bool] in SSReflect strongly
relies on the _views_ machinery, so let us begin by describing it
first.

%\newpage%

* Proving with views in SSReflect
%\label{sec:views}\index{views|textbf}%

*)

Require Import ssreflect.

(** 

Let us assume we have the following implication to prove:

*)

Lemma imp_trans4 P Q R S: (P -> Q) -> (R -> S) -> (Q -> R) -> P -> S.
Proof.
move=>H1 H2 H3.

(** 
[[
  P : Type
  Q : Type
  R : Type
  S : Type
  H1 : P -> Q
  H2 : R -> S
  H3 : Q -> R
  ============================
   P -> S
]]

Since we are proficient in the proofs via implications, it is not
difficult to construct the explicit proof term by a series of [apply:]
tactic calls or via the [exact:] tactic, as it has been show in
%Chapter~\ref{ch:logic}%. Let us do something different, though,
namely _weaken_ the top assumption of the goal by means of applying
the hypothesis [H1] to it, so the overall goal will become [Q -> S].

*)

move=>p; move: (H1 p).

(** 

This proof pattern of "switching the view" turns out to be so frequent
that SSReflect introduces a special _view_ tactical %\texttt{/}% for
it, which is typically combined with the standard [move] or [case]
tactics. In particular, the last proof line could be replaced by the
following:

*)

Undo.
move/H1.

(** 

The assumption [H1] used for weakening is usually referred to as a
%\index{view lemma}% _view lemma_. The spaces before and after
%\texttt{/}% are optional. One can also _chain_ the views into one
series, so the current proof can be completed as follows:

*)

by move/H3 /H2.
Qed.

(** 

** Combining views and bookkeeping

The view tactical can be also combined with the standard bookkeeping
machinery, so it will apply the specified view lemma to the
corresponding assumption of the goal, as demonstrated by the following
proof script, which use the partially-applied assumption [H p] as a
view lemma:

*)

Goal forall P Q R, P -> (P -> Q -> R) -> Q -> R.
Proof.
by move=>P Q R p H /(H p).

(**

In fact, this prove can be shortened even further by using the view
notation for the _top_ assumption:

*)

Undo.
move=> P Q R p. 
by move/(_ p). 
Qed.

(** 

The last proof script first moved for assumptions to the context, so
the goal became [(P -> Q -> R) -> R]. Next, it partially applied the
top assumption [(P -> Q -> R)] to [p : P] from the context and moved
the result back to the goal, so it became [(P -> Q) -> P -> Q], which
is trivially provable.

It is also possible to use views in combination with the [case]
tactics, which first performs the "view switch" via the view lemma
provided and then case-analyses on the result, as, demonstrated by the
following proof script:

*)

Goal forall P Q R, (P -> Q /\ R) -> P -> R.
Proof.
move=> P Q R H.
by case/H. 
Qed.

(** 

What is happened is that the combined tactic [case/H] first switched
the top assumption of the goal from [P] to [Q /\ R] and then
case-analyses on it, which gave the proof of [R] right away, allowing
us to conclude the proof.

** Using views with equivalences
%\label{seq:viewseq}%

So far we have explored only views that help to weaken the hypothesis
using the view lemma, which is an implication. In fact, SSReflect's
view mechanism is elaborated enough to deal with view lemmas defined
by means of equivlance (double implication) %\texttt{<->}%, and the
system can figure out itself, "in which direction" the view lemma
should be applied. Let us demonstrate it with the following example,
which makes use of the hypothesis [PQequiv],%\footnote{The Coq's
command \texttt{Hypothesis} is a synonym for \texttt{Axiom} and
\texttt{Variable}.\ccom{Hypothesis}\ccom{Variable}\ccom{Axiom}}% whose
nature is irrelevant for the illustration purposes:

*)

Variables S T: bool -> Prop.
Hypothesis STequiv : forall a b, T a <-> S (a || b). 

Lemma ST_False a b: (T a -> False) -> S (a || b) -> False.
Proof.
by move=>H /STequiv.
Qed.

(**

** Declaring view hints

Let us get back to the example from %Section~\ref{seq:viewseq}%, in
which we have seen how views can deal with equalities. The mentioned
elaboration, which helped the system to recognize, in which direction
the double implication hypothesis [STequiv] should have been used, is
not hard-coded into SSReflect. Instead, it is provided by a flexible
mechanism of %\index{view hints}% _view hints_, which allows one to
specify view lemmas that should be applied _implicitly_ whenever it is
necessary and can be figured out unambiguously.

In the case of the proof of the [ST_False] lemma the view hint [iffRL]
from the included module [ssreflect]%\footnote{Implicit view hints are
defined by means of \texttt{Hint View}\ccom{Hint View} command, added
to Coq by SSReflect. See the implementation of the module
[ssrbool]\ssrm{ssrbool} and Section 9.8 of the Reference
Manual~\cite{Gontier-al:TR}.}% %\ssrm{ssreflect}% has been "fired" in
order to adapt the hypothesis [STequiv], so the adapted variant could
be applied as a view lemma to the argument of type [S (a || b)].

*)

Check iffRL.

(** 

The type of [iffRL] reveals that what it does is simply switching the
equivalence to the implication, which works right-to-left, as captured
by the name. Let us now redo the proof of the [ST_False] lemma to see
what is happening under the hood:

*)

Lemma ST_False' a b: (T a -> False) -> S (a || b) -> False.
Proof.
move=> H.
move/(iffRL (STequiv a b)).
done.
Qed.

(**

The view switch on the second line of the proof is what has been done
automatically in the previous case: the implicit view [iffRL] has been
applied to the call of [STequiv], which was in its turn supplied the
necessary arguments [a] and [b], inferred by the system from the goal,
so the type of [(STequiv a b)] would match the parameter type of
[iffRL], and the whole application would allow to make a view switch
in the goal.  What is left behind the scenes is the rest of the
attempts made by Coq/SSReflect in its search for a suitable implicit
view, which ended when the system has finally picked [iffRL].

In general, the design of powerful view hints is non-trivial, as they
should capture precisely the situation when the "view switch" is
absolutely necessary and the implicit views will not "fire"
spuriously. In the same time, implicit view hints is what allows for
the smooth implementation of the boolean reflection, as we will
discuss in %Section~\ref{sec:reflect}%.


** Applying view lemmas to the goal

Similarly to how they are used for _assumptions_, views can be udes to
interpret the goal by means of combiningy the Coq's standard [apply]
and [exact] tactics with the view tactical%~\texttt{/}%. In the case
is [H] is a view lemma, which is just an implication [P -> Q], where
[Q] is the statement of the goal, the enhanced tactic [apply/ P] will
work exactly as the standard SSReflect's [apply:], that is, it will
replace the goal [Q] with [H]'s assumption [P] to prove.

However, interpreting goals via views turns out to be very beneficial
in the presence of implicit view hints. For example, let us consider
the following proposition to prove.

*)

Definition TS_neg: forall a, T (negb a) -> S ((negb a) || a).
Proof.
move=>a H. 
apply/STequiv.
done.
Qed.

(** 

The view switch on the goal by via [apply/STequiv] changes the goal
from [S ((negb a) || a)] to [T (negb a)], so the rest of the proof
becomes trivial. Again, notice that the system managed to infer the
right arguments for the [STequiv] hypothesis by analysing the goal.

Now, if we print the body of [TS_neg] (we can do it since it has been
defined via [Definition] rather than [Theorem]), we will be able to
see how an application of the implicit application of the view lemma
[iffLR] of type [forall P Q : Prop, (P <-> Q) -> P -> Q] has been
inserted, allowing for the construction of the proof term:

*)

Print TS_neg.

(**

[[
TS_neg = 
  fun (a : bool) (H : T (negb a)) =>
  (fun F : T (negb a) =>
     iffLR (Q:=S (negb a || a)) (STequiv (negb a) a) F) H
     : forall a : bool, T (negb a) -> S (negb a || a)
]]

*)


(** * %\texttt{Prop} versus \emph{bool}%
%\label{sec:propbool}%

As we have already explored in the previous chapters, in CIC, the
logical foundation of Coq there is a number of important distinction
between logical propositions and boolean values. There is an infinite
number of ways to represent different propositions in the sort [Prop]
by means of defining the datatypes. In contrast, the type [bool] is
represented just by two values: [true] and [false]. Moreover, as it
was discussed in %Chapter~\ref{ch:logic}%, in Coq only those
propositions are considered to be _true_, whose proof term can be
constructed. And, of course, there is no such thing as a "proof term
of [true]", as [true] is simply a value. 

A more interesting question, though, is for which propositions [P] the
proofs can be computed _automatically_ by means of running a program,
whose result will be an answer to the question "Whether [P]
holds?". Therefore, such program should always _terminate_ and, upon
terminating, say "true" or "false". The propositions, for which a
construction of such program (even a very inefficient one) is
possible, are referred to %\index{decidability}% as _decidable_
ones. Alas, as it was discussed in %Section~\ref{sec:propsort} of
Chapter~\ref{ch:logic}%, quite a lot of interesting propositions are
undecidable. Such properties include the classical halting problem
%\index{halting problem}% ("Whether the program [p] terminates or
not?") and any higher-order formulae, i.e., such that contain
quantifiers. For instance, it is not possible to implement a
higher-order function, which would take two arbitrary functions $f_1$
and $f_2$ of type [nat -> nat] and return a boolean answer, which
would indicate whether these two functions are equal (point-wise) or
not, as it would account to checking the result of the both on each
natural number, which, clearaly, wouldn't terminate. Therefore, the
function equality is a good example of a proposition, which is is
undecidable in general, so we cannot provide a terminating procedure
for any values of its arguments (i.e., $f_1$ and $f_2$)

However, the _undecidability_ of higher-order propositions (like the
functional equality) does not make them _non-provable_ for particular
cases, as we have clearly observed thorough the past few chapters. It
usualy take a human intuition, though, to construct a proof of an
undecidable proposition by means of combining a number of hypotheses
(i.e., constructing a proof terms), which is what one does when
building a proof using tactics in Coq. For instance, if we have some
extra insight about the two functions $f_1$ and $f_2$, which are
checked for equality, we might be able to construct the proof of them
being equal or not, in the similar ways as we have carried the proofs
so far. Again, even if the functions are unknown upfront, it does not
seem possible to implement an always-terminating procedure that would
automatically decide whether they are equal or not.

The above said does not mean that all possible propositions should be
implemented as instances of [Prop], making their clients to construct
the always construct their proofs, when it is necessary, since,
fortunally, some propositions as _decidable_, so it is possible to
construct a decision procedure for them. A good example of such
proposition is a predicate, which ensures that a number [n] is
prime. Of course, in Coq one can easily encode primality of a natural
number by means of the following inductive predicate, which ensures
that [n] is [0], [1] or has no other natural divisors but [1] and [n]
itself.

*)

Inductive isPrime n : Prop := 
 | IsZero of n = 0
 | IsOne of n = 1
 | IsOther of forall n1 n2, n = n1 * n2 -> (n1 = 1 /\ n2 = n) \/ (n1 = n /\ n2 = 1).

(** 

Such definition, although correct, is quite inconvenient to use, as it
does not provide a direct way to _check_ whether some particular
number (e.g., 239) is prime or not. Instead, it requires on to
construct a proof of primality for _each_ particular case using the
constructors (or the contradiction, which would imply that the number
is not prime). As it's well known, there is a terminating procedure to
compute whether the number is prime or not by means of _enumerating_
all potential divisors of [n] from [1] to the square root of [n]. Such
procedure is actually implemented in the SSReflect's [prime]
%\ssrm{prime}% module and proved correct with respect to the
definition similar to the one above,%\footnote{Although the
implementation and the proof are somewhat non-trivial, as they require
to build a primitively-recursive function, which performs the
enumeration, so we do not consider them here.}% so now one can test
the numbers by equality by simply _executing_ the appropriate function
and getting a boolean answer:

*)

Require Import ssrnat prime.
Eval compute in prime 239.
(** 
[[
     = true
     : bool
]]

Therefore, we can summarize that the _decidability_ is what draws the
line between propositions encoded by means of Coq's [Prop] datatypes
and procedures, returning a [bool] result. [Prop] provides a way to
encode a larger class of logical statements, in particular, thanks to
the fact that it allows to use quantifiers and, therefore encode
higher-order propositions. The price to pay for the expressivity is
the necessity to explicitly construct the proofs of the encoded
statements, which might lead to series of tedious and repetitive
scripts. [bool]-returning functions, when implemented in Coq, are
decidable by construction (as Coq enforces termination), and,
therefore, provide a way to compute the propositions they
implement. Of course, in order to be reduce to [true] or [false], all
quantifiers should be removed by means of instantiated the
corresponding bound variables, after which the computation becomes
possible. 

For instance, while the expression [(prime 239) || (prime 42)] can be
evaluated to [true] right away, whereas the expression

[[
forall n, (prime n) || prime (n +1)
]]

is not even well-typed (as polymorphic [forall]-quantification in Coq
does not admit primitive types). This expression can be, however,
_coreced_ into [Prop] by means of comparing the boolean expresion with
[true] using the propositional equality:

[[
forall n, ((prime n) || prime (n +1) = true)
]]

This last example brings us to the insight that the [bool]-returning
functions (i.e., decidable predicates) can be naturally _injected_
%\index{injection}% into propositions of sort [Prop] by simply
comparing their result with [true] via propositional equality. This is
what is done by SSReflect automatically using the implicit
%\index{coercion}\ccom{Coercion}% _coercion_, imported by the
[ssrbool] module:%\ssrm{ssrbool}%

[[
Coercion is_true (b: bool) := b = true
]]

This coersion can be seen as an implicit type conversion, familiar
from the languages like Scala or Haskell, and it inserted by Coq
automatically every time it expect to see a value of sort [Prop], but
instead encounters a boolean value. Let us consider the following goal
as an example:

*)

Require Import ssrbool.
Goal prime (16 + 14) -> False.
Proof. done. Qed.

(** 

As we can see, the proof is rather short, and, in fact, done by
Coq/SSReflect fully automatically. In fact, the system first
_computes_ the value of [prime (16 + 14)], which is, obviously
[false]. Then the boolean value [false] is coerced into the
propositional equality [false = true], as previously described. The
equality is then automatically discriminated (%see
Section~\ref{sec:discr}%), which allows the system to infer the
falsehood, completing the proof.

This example and the previous discussion should convey the idea that
_decidable propositions should be implemented as computable functions
returning a boolean result_. This simple design pattern makes it
possible to take full advantage of the computational power of Coq as a
programming language and prove decidable properties automatically,
rather then by means of emposing a burden of constructing an explicit
proof. Whe have shown how a boolean result can be easily injected back
to the world of propositions. This computational approach to proofs is
what has been taken by SSReflect to the extreme, making the proofs
about common mathematical constructions to be very short, as most of
the proof obligrations simply _do not appear_, as the system is
possible to reduce them by means of performing the computations on the
fly. Even though, as discussed, some propositions can be only encoded
as elements of [Prop], our general advice is to rely on the
computations whenever it is possible.

In the following subsections we will elaborate on some additional
specifications and proof patterns, which are enabled by using boolean
values instead of full-fledged propositions from [Prop].

** Using conditionals in predicates

The ternary conditional operator [if-then-else] is something that
programmers use on a regular basis. However, when it comes to the
specifications in the form of Coq's standard propositions it turns out
one cannot simply employ the [if-then-else] connective in them, as it
expects its conditional argument to be of type [bool]. This
restriction is, again, a consequence of the fact that the result of
[if-then-else] expression should be computable, which conflicts with
the fact that not every proposition is decidable and, hence, there is
no sound way overload the conditional operator, so it would rely on
the existence of the proof of its conditional (or its negation).

[[
Definition prime_spec_bad n m : Prop := m = (if isPrime n then 1 else 2).

Error: In environment
m : nat
n : nat
The term "isPrime n" has type "Prop" while it is expected to have type "bool".
]]

Fortunately, the computable predicates are free from this problem, so
on can freely use them in the conditionals:

*)

Definition prime_spec n m : Prop := m = (if prime n then 1 else 2).

(**

** Case analysing on a boolean assumption

Another advantage of the boolean predicates is that they automatically
come with a natural case analysis principle: reasoning about an
outcome of a particular predicate, one can always consider two
possibilities: when it returned [true] or [false]. This makes is
particularly pleasant to reason about the programs and specifications
that use conditional, which is demonstrated by the following example.

*)

Definition discr_prime n := (if prime n then 0 else 1) + 1.

(** 

Let us now prove that the definition [prime_spec] gives a precise
specification of the function [discr_prime]:

*)

Lemma discr_prime_spec : forall n, prime_spec n (discr_prime n).
Proof.
move=>n. rewrite /prime_spec /discr_prime.

(**

The proof of the specification is totally in the spirit of what one
would have done when proving it manually: we just case-analyse on the
value of [prime n], which is either [true] or [false]. Similarly to
the way the rewritings are handled by means of unification, in both
cases the system substitutes [prime n] with its boolean value in the
specification as well. The evaluation completes the proof.

*)

by case: (prime n)=>//.
Qed.

(**

Another commonly used case of a boolean predicate to perform a case
analysis on is _computable equality_, which can be employed in the
proof proceeding by an argument "let us assume [a] to be equal to [b]
(or not)". As already hinted by the example with the function equality
earlier in this section, the computable equality is not always
possible to implement. Fortunately, it can be implemented for a large
class of datatypes, such as booleans, natural numbers, lists and sets
(of elements with computable equality), and it was implemented in
SSReflect, so one can take an advantage of it in the
proofs.%\footnote{The way the computable equality is encoded so it
would work uniformly for different types is a lar topic by itself, so
we postpone its explanation until Chapter~\ref{ch:depstruct}}%

*)

(** * %The \textsf{\textbf{reflect}} type family%
%\label{sec:reflect}%



Construct a simple reflection procedure for some simple user-specific
connective.

*)


(* begin hide *)
Module Inner.
(* end hide *)
Inductive reflect (P : Prop) : bool -> Set :=
  | ReflectT  of   P : reflect P true
  | ReflectF of ~ P : reflect P false.
(* begin hide *)
End Inner.
(* end hide *)

Lemma andl_b a b: a && b -> a.
Proof.
by case/andP.
Show Proof.

(**
[[
(fun (a b : bool) (top : a && b) =>
 (fun F: forall (a0 : a) (b0 : b),
         (fun _ : a /\ b => is_true a) (conj a0 b0) =>
  match elimTF andP top 
  as a0 return ((fun _ : a /\ b => is_true a) a0)
  with
  | conj x x0 => Fx x0
  end) (fun (a0 : a) (_ : b) => a0))
]]

*)

Qed.

(**

** Reflecting logical connectives

*)

Goal forall a b c : bool, [|| false, false, true | false].
move=> a b c.
done.
Qed.

(** 

** Reflecting decidable equalities


*)

Require Import eqtype.
Definition foo (x y: nat) := if x == y then 1 else 0.

Goal forall x y, x = y -> foo x y = 1.
Proof.
move=>x y; rewrite /foo.
by move/eqP=>->.
Qed.

(** 

%\begin{exercise}[Reflecting exclusive disjunction]%

Let us define a propositional version of the _exclusive or_
%\index{exclusive disjunction}% predicate:

*)

Definition XOR (P Q: Prop) := (P \/ Q) /\ ~(P /\ Q).

(** 

as well as its boolean version (in a curried form, so it takes just
one argument and returns a function):

*)

Definition xorb b := if b then negb else fun x => x.

(** 

Now, prove the following _generalized_ reflection lemma [xorP_gen] and
its direct consequence, the usual refletion lemma [xorP]:

%\hint% Recall that the _reflect_ predicate is just a rewriting rule,
 so one can perform a case analysis on it.

*)

Lemma xorP_gen (b1 b2 : bool)(P1 P2: Prop): 
  reflect P1 b1 -> reflect P2 b2 -> reflect (XOR P1 P2) (xorb b1 b2).
(* begin hide *)
Proof.
case=>H1; case=>H2; constructor; rewrite /XOR. 
- by case; case=>H; apply.
- split; first by left. 
  by case=>_ H; apply: H2.
- split; first by right.
  by case=>H _; apply: H1.
- intuition.
Qed.
(* end hide *)

Lemma xorP (b1 b2 : bool): reflect (XOR b1 b2) (xorb b1 b2).
Proof.
(* begin hide *)
by apply: xorP_gen; case:b1=>//=; case:b2=>//=; constructor.
(* end hide *)
Qed.

(** 
%\end{exercise}%

%\begin{exercise}[Alternative formulation of exclusive disjunction]%

Let us consider an alternative version of exclusive or, defined by
means of the predicate [XOR']:

*)

Definition XOR' (P Q: Prop) := (P /\ ~Q) \/ (~P /\ Q).
(** 

Prove the following equivalence lemma between to versions of [XOR]:

*)

Lemma XORequiv P Q: XOR P Q <-> XOR' P Q.
(* begin hide *)
Proof.
split. 
- case; case=>[p|q] H. 
  - by left; split=>// q; apply: H.
  by right; split=>// p; apply H.
case; case=>p q.
- split=>[| H]; first by left.
  by apply: q; case: H.
split; first by right. 
by case=>/p.
Qed.
(* end hide *)

(** 

The final step is to use the equivalence we have just proved in order
to establish an alternative version of the reflective correspondence
of exclusive disjuntion.

%\hint% Use the [Search] machinery to look for lemmas that might help
 to leverage the equivalence between two predicates and make the
 following proof to be a one-liner.

*)

(* Search _ (reflect _ _). *)
Lemma xorP' (b1 b2 : bool): reflect (XOR' b1 b2) (xorb b1 b2).
(* begin hide *)
Proof.
by apply: (equivP (xorP b1 b2) (XORequiv _ _)).
Qed.
(* end hide *)
 
(** 

%\end{exercise}%

Unsurprisingly, every statement about exclusive or, e.g., its
commutativity and associativity, is extremely easy to prove when it is
considered as a boolean function. 

*)

Lemma xorbC (b1 b2: bool) : (xorb b1 b2) = (xorb b2 b1). 
Proof. by case: b1; case: b2=>//. Qed.

Lemma xorbA (b1 b2 b3: bool) : (xorb (xorb b1 b2) b3) = (xorb b1 (xorb b2 b3)). 
Proof. by case: b1; case: b2; case: b3=>//. Qed.

(** 

It is also not difficult to prove the propositional counterparts of
the above lemmas for decidable propositions, reflected by them, hence
the following exercise.

%\begin{exercise}%

Prove the following specialized lemmas for decidable propositions
represented y booleans:

*)

Lemma xorCb (b1 b2: bool) : (XOR b1 b2) <-> (XOR b2 b1). 
(* begin hide *)
Proof.
by split; move/xorP; rewrite xorbC; move/xorP.
Qed.
(* end hide *)

Lemma xorAb (b1 b2 b3: bool) : (XOR (XOR b1 b2) b3) <-> (XOR b1 (XOR b2 b3)). 
(* begin hide *)
Proof.
split=>H. 
apply: (xorP_gen b1 (xorb b2 b3) b1 (XOR b2 b3)); first by case: b1 {H}; constructor.
- by apply/xorP.
- rewrite -xorbA. 
  apply/(xorP_gen (xorb b1 b2) b3 (XOR b1 b2) b3)=>//; first by apply/xorP. 
  case: b3 {H} =>//; constructor=>//.
apply: (xorP_gen (xorb b1 b2) b3 (XOR b1 b2) b3). 
- by apply/xorP.
- case: b3 {H}; constructor=>//.
rewrite xorbA. 
apply/(xorP_gen b1 (xorb b2 b3) b1 (XOR b2 b3))=>//; last by apply/xorP. 
case: b1 {H} =>//; constructor=>//.
Qed.
(* end hide *)

(** 

%\hint% In the proof of [xorAb] the generalized reflection lemma
 [xorP_gen] might come in handy.

%\hint% A redundant assumption [H] in the context can be erased by
 typing [clear H] %\ttac{clear}% or [move => {H}]. The latter form can
 be combined with any bookkeeping sequence, not only with [move]
 tactics.

%\hint% The Coq's embedded tactic [intuition] can be helpful for
 automatically solving goals in propositional logic.%\ttac{intuition}%

%\end{exercise}%

*)



(* begin hide *)
End BoolReflect.
(* end hide *)
