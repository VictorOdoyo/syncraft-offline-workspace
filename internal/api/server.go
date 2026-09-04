package api

import (
 "encoding/json"
 "errors"
 "io"
 "net/http"
 "strconv"
 "strings"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/auth"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/store"
)
type Server struct {Store store.Store;Auth *auth.Service;Origins []string;Hub *Hub}
func(s *Server)Handler()http.Handler{
 mux:=http.NewServeMux()
 mux.HandleFunc("GET /health/live",func(w http.ResponseWriter,r *http.Request){write(w,200,map[string]string{"status":"alive"})})
 mux.HandleFunc("GET /health/ready",func(w http.ResponseWriter,r *http.Request){if err:=s.Store.Ping(r.Context());err!=nil{write(w,503,map[string]string{"error":"storage unavailable"});return};write(w,200,map[string]string{"status":"ready"})})
 mux.HandleFunc("POST /api/v1/login",s.login)
 mux.HandleFunc("POST /api/v1/devices",s.register)
 mux.HandleFunc("GET /api/v1/devices",s.devices)
 mux.HandleFunc("POST /api/v1/devices/{id}/revoke",s.revoke)
 mux.HandleFunc("POST /api/v1/sync/push",s.push)
 mux.HandleFunc("GET /api/v1/sync/pull",s.pull)
 mux.HandleFunc("GET /api/v1/audit",s.audit)
 mux.HandleFunc("POST /api/v1/attachments/{id}",s.upload)
 mux.HandleFunc("GET /api/v1/attachments/{id}",s.download)
 mux.HandleFunc("GET /api/v1/attachments",s.attachments)
 mux.HandleFunc("GET /api/v1/events",s.events)
 return s.middleware(mux)
}
func write(w http.ResponseWriter,status int,value any){w.Header().Set("Content-Type","application/json");w.WriteHeader(status);_ =json.NewEncoder(w).Encode(value)}
func problem(w http.ResponseWriter,err error){status,msg:=500,"internal service error";switch{case errors.Is(err,domain.ErrInvalid):status,msg=400,err.Error();case errors.Is(err,domain.ErrConflict):status,msg=409,err.Error();case errors.Is(err,domain.ErrForbidden):status,msg=403,err.Error();case errors.Is(err,domain.ErrNotFound):status,msg=404,err.Error()};write(w,status,map[string]string{"error":msg})}
func decode(w http.ResponseWriter,r *http.Request,v any)bool{r.Body=http.MaxBytesReader(w,r.Body,2<<20);d:=json.NewDecoder(r.Body);d.DisallowUnknownFields();if d.Decode(v)!=nil{problem(w,domain.ErrInvalid);return false};if d.Decode(new(any))!=io.EOF{problem(w,domain.ErrInvalid);return false};return true}
func(s *Server)identity(w http.ResponseWriter,r *http.Request,edit,device bool)(auth.Claims,bool){token:=strings.TrimPrefix(r.Header.Get("Authorization"),"Bearer ");c,err:=s.Auth.Verify(token);if err!=nil{write(w,401,map[string]string{"error":"authentication required"});return c,false};if edit && c.Role!="editor" && c.Role!="admin"{problem(w,domain.ErrForbidden);return c,false};if device{d,err:=s.Store.Device(r.Context(),c.Workspace,r.Header.Get("X-Device-ID"));if err!=nil || d.Revoked || d.Actor!=c.Subject{problem(w,domain.ErrForbidden);return c,false}};return c,true}
func(s *Server)login(w http.ResponseWriter,r *http.Request){var req struct{Username string `json:"username"`;Password string `json:"password"`};if !decode(w,r,&req){return};if len(req.Username)>100 || len(req.Password)>256{problem(w,domain.ErrInvalid);return};token,err:=s.Auth.Login(req.Username,req.Password);if err!=nil{write(w,401,map[string]string{"error":"invalid credentials"});return};write(w,200,map[string]string{"token":token})}
func(s *Server)register(w http.ResponseWriter,r *http.Request){c,ok:=s.identity(w,r,false,false);if !ok{return};var req struct{ID string `json:"id"`;Name string `json:"name"`};if !decode(w,r,&req){return};if !domain.ValidID(req.ID) || strings.TrimSpace(req.Name)=="" || len(req.Name)>100{problem(w,domain.ErrInvalid);return};d:=domain.Device{ID:req.ID,Name:req.Name,Actor:c.Subject};if err:=s.Store.Register(r.Context(),c.Workspace,d);err!=nil{problem(w,err);return};write(w,201,d)}
func(s *Server)devices(w http.ResponseWriter,r *http.Request){c,ok:=s.identity(w,r,false,true);if !ok{return};rows,err:=s.Store.Devices(r.Context(),c.Workspace);if err!=nil{problem(w,err);return};write(w,200,rows)}
func(s *Server)revoke(w http.ResponseWriter,r *http.Request){c,ok:=s.identity(w,r,false,true);if !ok{return};id:=r.PathValue("id");if !domain.ValidID(id){problem(w,domain.ErrInvalid);return};d,err:=s.Store.Device(r.Context(),c.Workspace,id);if err!=nil{problem(w,err);return};if c.Role!="admin" && d.Actor!=c.Subject{problem(w,domain.ErrForbidden);return};if err=s.Store.Revoke(r.Context(),c.Workspace,id,c.Subject);err!=nil{problem(w,err);return};s.Hub.Notify(c.Workspace);write(w,200,map[string]bool{"revoked":true})}
func(s *Server)push(w http.ResponseWriter,r *http.Request){c,ok:=s.identity(w,r,true,true);if !ok{return};var req struct{Operations []domain.Operation `json:"operations"`};if !decode(w,r,&req){return};cursor,err:=s.Store.Push(r.Context(),c.Workspace,r.Header.Get("X-Device-ID"),c.Subject,req.Operations);if err!=nil{problem(w,err);return};s.Hub.Notify(c.Workspace);write(w,200,map[string]int64{"cursor":cursor})}
func cursor(r *http.Request)(int64,error){v:=r.URL.Query().Get("after");if v==""{return 0,nil};n,err:=strconv.ParseInt(v,10,64);if err!=nil || n<0{return 0,domain.ErrInvalid};return n,nil}
func(s *Server)pull(w http.ResponseWriter,r *http.Request){c,ok:=s.identity(w,r,false,true);if !ok{return};after,err:=cursor(r);if err!=nil{problem(w,err);return};page,err:=s.Store.Pull(r.Context(),c.Workspace,after,100);if err!=nil{problem(w,err);return};write(w,200,page)}
func(s *Server)audit(w http.ResponseWriter,r *http.Request){c,ok:=s.identity(w,r,false,true);if !ok{return};after,err:=cursor(r);if err!=nil{problem(w,err);return};rows,err:=s.Store.Audit(r.Context(),c.Workspace,after,100);if err!=nil{problem(w,err);return};write(w,200,rows)}
