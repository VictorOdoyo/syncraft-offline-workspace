package api

import (
 "bytes"
 "encoding/json"
 "fmt"
 "net/http"
 "net/http/httptest"
 "testing"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/auth"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/store"
)
const deviceID="00000000-0000-4000-8000-000000000001"
const recordID="00000000-0000-4000-8000-000000000010"
func fixture(t *testing.T)(*Server,http.Handler,string){t.Helper();a:=&auth.Service{Secret:[]byte("testing-signing-key-with-32-bytes"),Users:auth.DemoUsers()};s:=&Server{Store:store.NewMemory(),Auth:a,Hub:NewHub(),Origins:[]string{"http://localhost:5176"}};token,err:=a.Login("inspector","local-demo");if err!=nil{t.Fatal(err)};h:=s.Handler();r:=request(h,"POST","/api/v1/devices",token,`{"id":"`+deviceID+`","name":"Field tablet"}`);if r.Code!=201{t.Fatal(r.Body)};return s,h,token}
func request(h http.Handler,method,path,token,body string)*httptest.ResponseRecorder{r:=httptest.NewRequest(method,path,bytes.NewBufferString(body));r.Header.Set("Authorization","Bearer "+token);r.Header.Set("X-Device-ID",deviceID);r.Header.Set("Content-Type","application/json");w:=httptest.NewRecorder();h.ServeHTTP(w,r);return w}
func TestSyncLifecycle(t *testing.T){_,h,token:=fixture(t);body:=fmt.Sprintf(`{"operations":[{"id":"00000000-0000-4000-8000-000000000002","record":"%s","field":"title","value":"Pump inspection","parents":[]}]}`,recordID)
 for range 2{r:=request(h,"POST","/api/v1/sync/push",token,body);if r.Code!=200{t.Fatal(r.Code,r.Body)}}
 r:=request(h,"GET","/api/v1/sync/pull",token,"");var p struct{Entries []any `json:"entries"`;Cursor int `json:"cursor"`};if json.Unmarshal(r.Body.Bytes(),&p)!=nil || p.Cursor!=1 || len(p.Entries)!=1{t.Fatal(r.Body)}
 if r=request(h,"GET","/api/v1/sync/pull?after=-1",token,"");r.Code!=400{t.Fatal(r.Code)}
 if r=request(h,"POST","/api/v1/devices/"+deviceID+"/revoke",token,`{}`);r.Code!=200{t.Fatal(r.Body)}
 if r=request(h,"GET","/api/v1/sync/pull",token,"");r.Code!=403{t.Fatal(r.Code)}
}
func TestRolesAndStrictBodies(t *testing.T){s,h,token:=fixture(t);observer,_:=s.Auth.Login("observer","local-demo");if r:=request(h,"POST","/api/v1/sync/push",observer,`{"operations":[]}`);r.Code!=403{t.Fatal(r.Code)};if r:=request(h,"GET","/api/v1/audit","invalid","");r.Code!=401{t.Fatal(r.Code)};if r:=request(h,"POST","/api/v1/devices",token,`{"unknown":true}`);r.Code!=400{t.Fatal(r.Code)};if r:=request(h,"POST","/api/v1/devices",token,`{} {}`);r.Code!=400{t.Fatal(r.Code)}}
func TestBrowserOrigins(t *testing.T){_,h,_:=fixture(t);r:=httptest.NewRequest("OPTIONS","/api/v1/sync/pull",nil);r.Header.Set("Origin","https://untrusted.example");w:=httptest.NewRecorder();h.ServeHTTP(w,r);if w.Code!=403{t.Fatal(w.Code)};r.Header.Set("Origin","http://localhost:5176");w=httptest.NewRecorder();h.ServeHTTP(w,r);if w.Code!=204 || w.Header().Get("Access-Control-Allow-Origin")==""{t.Fatal(w.Code,w.Header())}}
