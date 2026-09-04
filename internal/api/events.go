package api
import("context";"encoding/json";"net/http";"net/url";"sync";"time";"github.com/coder/websocket")
type Hub struct{mu sync.Mutex;listeners map[string]map[chan struct{}]bool}
func NewHub()*Hub{return &Hub{listeners:map[string]map[chan struct{}]bool{}}}
func(h *Hub)Notify(w string){h.mu.Lock();defer h.mu.Unlock();for ch:=range h.listeners[w]{select{case ch<-struct{}{}:default:}}}
func(h *Hub)subscribe(w string)(chan struct{},func()){h.mu.Lock();defer h.mu.Unlock();if h.listeners[w]==nil{h.listeners[w]=map[chan struct{}]bool{}};ch:=make(chan struct{},1);h.listeners[w][ch]=true;return ch,func(){h.mu.Lock();defer h.mu.Unlock();delete(h.listeners[w],ch);if len(h.listeners[w])==0{delete(h.listeners,w)}}}
func(s *Server)events(w http.ResponseWriter,r *http.Request){patterns:=[]string{};for _,origin:=range s.Origins{u,err:=url.Parse(origin);if err==nil{patterns=append(patterns,u.Host)}};conn,err:=websocket.Accept(w,r,&websocket.AcceptOptions{OriginPatterns:patterns});if err!=nil{return};defer conn.CloseNow();conn.SetReadLimit(4096)
 ctx,cancel:=context.WithTimeout(r.Context(),5*time.Second);_,raw,err:=conn.Read(ctx);cancel();if err!=nil{return};var hello struct{Token string `json:"token"`;Device string `json:"device"`};if json.Unmarshal(raw,&hello)!=nil{return};claims,err:=s.Auth.Verify(hello.Token);if err!=nil{_ =conn.Close(websocket.StatusPolicyViolation,"authentication required");return}
 valid:=func()bool{d,err:=s.Store.Device(r.Context(),claims.Workspace,hello.Device);return err==nil && !d.Revoked && d.Actor==claims.Subject && claims.ExpiresAt.After(time.Now())};if !valid(){_ =conn.Close(websocket.StatusPolicyViolation,"device denied");return}
 ch,remove:=s.Hub.subscribe(claims.Workspace);defer remove();readCtx:=conn.CloseRead(r.Context());ticker:=time.NewTicker(15*time.Second);defer ticker.Stop()
 send:=func()error{ctx,cancel:=context.WithTimeout(readCtx,5*time.Second);defer cancel();return conn.Write(ctx,websocket.MessageText,[]byte(`{"type":"sync-needed"}`))};if send()!=nil{return}
 for{select{case <-readCtx.Done():return;case <-ticker.C:if !valid(){_ =conn.Close(websocket.StatusPolicyViolation,"session ended");return};if send()!=nil{return};case <-ch:if !valid(){_ =conn.Close(websocket.StatusPolicyViolation,"device revoked");return};if send()!=nil{return}}}
}
