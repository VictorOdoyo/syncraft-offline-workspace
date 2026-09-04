package domain

import (
 "slices"
 "sort"
)

// Equivalent ignores parent ordering; the causal context is a set.
func Equivalent(a,b Operation) bool {
 if a.ID!=b.ID || a.Record!=b.Record || a.Field!=b.Field || a.Value!=b.Value {return false}
 ap,bp:=slices.Clone(a.Parents),slices.Clone(b.Parents)
 sort.Strings(ap);sort.Strings(bp)
 return slices.Equal(ap,bp)
}

// Frontier retains concurrent versions rather than selecting a wall-clock winner.
func Frontier(ops []Operation, record, field string) []Operation {
 removed:=map[string]bool{}
 for _,o:=range ops {if o.Record==record && o.Field==field {for _,p:=range o.Parents {removed[p]=true}}}
 result:=[]Operation{}
 for _,o:=range ops {if o.Record==record && o.Field==field && !removed[o.ID] {result=append(result,o)}}
 sort.Slice(result,func(i,j int)bool{return result[i].ID<result[j].ID})
 return result
}

// ValidateBatch accepts causal order and idempotent retransmission, not cycles or missing parents.
func ValidateBatch(existing map[string]Operation, batch []Operation) error {
 if len(batch)==0 || len(batch)>100 {return ErrInvalid}
 known:=make(map[string]Operation,len(existing)+len(batch))
 for k,v:=range existing {known[k]=v}
 for _,o:=range batch {
  if err:=Validate(o);err!=nil{return err}
  if old,ok:=known[o.ID];ok {if !Equivalent(old,o){return ErrConflict};continue}
  for _,p:=range o.Parents {parent,ok:=known[p];if !ok || parent.Record!=o.Record || parent.Field!=o.Field{return ErrInvalid}}
  known[o.ID]=o
 }
 return nil
}
