package store

import (
 "context"
 _ "embed"
 "encoding/json"
 "errors"
 "time"
 "github.com/jackc/pgx/v5"
 "github.com/jackc/pgx/v5/pgxpool"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
)
//go:embed migrations/001_initial.sql
var migration string
type Postgres struct{pool *pgxpool.Pool}
func OpenPostgres(ctx context.Context,url string)(*Postgres,error){
 cfg,err:=pgxpool.ParseConfig(url);if err!=nil{return nil,err};cfg.MaxConns=10;cfg.MaxConnLifetime=time.Hour
 pool,err:=pgxpool.NewWithConfig(ctx,cfg);if err!=nil{return nil,err}
 tx,err:=pool.Begin(ctx);if err!=nil{pool.Close();return nil,err};defer tx.Rollback(ctx)
 if _,err=tx.Exec(ctx,"SELECT pg_advisory_xact_lock(734029)");err==nil{_,err=tx.Exec(ctx,migration)}
 if err==nil{err=tx.Commit(ctx)};if err!=nil{pool.Close();return nil,err};return &Postgres{pool},nil
}
func(p *Postgres)Close(){p.pool.Close()}
func(p *Postgres)Ping(ctx context.Context)error{return p.pool.Ping(ctx)}
func(p *Postgres)write(ctx context.Context,w string,fn func(pgx.Tx)error)error{
 tx,err:=p.pool.Begin(ctx);if err!=nil{return err};defer tx.Rollback(ctx)
 if _,err=tx.Exec(ctx,"INSERT INTO workspaces(id) VALUES($1) ON CONFLICT DO NOTHING",w);err!=nil{return err}
 if _,err=tx.Exec(ctx,"SELECT id FROM workspaces WHERE id=$1 FOR UPDATE",w);err!=nil{return err}
 if err=fn(tx);err!=nil{return err};return tx.Commit(ctx)
}
func logAudit(ctx context.Context,tx pgx.Tx,w,actor,action,target string)error{
 _,err:=tx.Exec(ctx,`WITH n AS (UPDATE workspaces SET audit_sequence=audit_sequence+1 WHERE id=$1 RETURNING audit_sequence)
 INSERT INTO audit_events(workspace,sequence,actor,action,target) SELECT $1,audit_sequence,$2,$3,$4 FROM n`,w,actor,action,target);return err
}
func(p *Postgres)Register(ctx context.Context,w string,d domain.Device)error{return p.write(ctx,w,func(tx pgx.Tx)error{
 var actor string;var revoked bool;err:=tx.QueryRow(ctx,"SELECT actor,revoked FROM devices WHERE workspace=$1 AND id=$2",w,d.ID).Scan(&actor,&revoked)
 if err==nil{if actor!=d.Actor || revoked{return domain.ErrForbidden};return nil};if !errors.Is(err,pgx.ErrNoRows){return err}
 if _,err=tx.Exec(ctx,"INSERT INTO devices(workspace,id,actor,name) VALUES($1,$2,$3,$4)",w,d.ID,d.Actor,d.Name);err!=nil{return err};return logAudit(ctx,tx,w,d.Actor,"device.registered",d.ID)
})}
func(p *Postgres)Device(ctx context.Context,w,id string)(domain.Device,error){d:=domain.Device{ID:id};err:=p.pool.QueryRow(ctx,"SELECT name,actor,revoked,created FROM devices WHERE workspace=$1 AND id=$2",w,id).Scan(&d.Name,&d.Actor,&d.Revoked,&d.Created);if errors.Is(err,pgx.ErrNoRows){err=domain.ErrNotFound};return d,err}
func(p *Postgres)Devices(ctx context.Context,w string)([]domain.Device,error){rows,err:=p.pool.Query(ctx,"SELECT id::text,name,actor,revoked,created FROM devices WHERE workspace=$1 ORDER BY created,id LIMIT 500",w);if err!=nil{return nil,err};defer rows.Close();out:=[]domain.Device{};for rows.Next(){var d domain.Device;if err=rows.Scan(&d.ID,&d.Name,&d.Actor,&d.Revoked,&d.Created);err!=nil{return nil,err};out=append(out,d)};return out,rows.Err()}
func(p *Postgres)Revoke(ctx context.Context,w,id,actor string)error{return p.write(ctx,w,func(tx pgx.Tx)error{var revoked bool;err:=tx.QueryRow(ctx,"SELECT revoked FROM devices WHERE workspace=$1 AND id=$2",w,id).Scan(&revoked);if errors.Is(err,pgx.ErrNoRows){return domain.ErrNotFound};if err!=nil{return err};if revoked{return nil};if _,err=tx.Exec(ctx,"UPDATE devices SET revoked=true WHERE workspace=$1 AND id=$2",w,id);err!=nil{return err};return logAudit(ctx,tx,w,actor,"device.revoked",id)})}
func(p *Postgres)Push(ctx context.Context,w,device,actor string,batch []domain.Operation)(int64,error){var cursor int64;err:=p.write(ctx,w,func(tx pgx.Tx)error{
 var owner string;var revoked bool;if err:=tx.QueryRow(ctx,"SELECT actor,revoked FROM devices WHERE workspace=$1 AND id=$2",w,device).Scan(&owner,&revoked);err!=nil || revoked || owner!=actor{return domain.ErrForbidden}
 if len(batch)==0 || len(batch)>100{return domain.ErrInvalid};known:=map[string]domain.Operation{}
 for _,o:=range batch{if err:=domain.Validate(o);err!=nil{return err};ids:=append([]string{o.ID},o.Parents...);for _,id:=range ids{if _,ok:=known[id];ok{continue};var raw []byte;err:=tx.QueryRow(ctx,"SELECT content FROM operations WHERE workspace=$1 AND id=$2",w,id).Scan(&raw);if errors.Is(err,pgx.ErrNoRows){continue};if err!=nil{return err};var stored domain.Operation;if err=json.Unmarshal(raw,&stored);err!=nil{return err};known[id]=stored}}
 if err:=domain.ValidateBatch(known,batch);err!=nil{return err}
 for _,o:=range batch{if _,ok:=known[o.ID];ok{continue};raw,err:=json.Marshal(o);if err!=nil{return err};_,err=tx.Exec(ctx,`WITH n AS (UPDATE workspaces SET sequence=sequence+1 WHERE id=$1 RETURNING sequence)
 INSERT INTO operations(workspace,id,sequence,device,actor,content) SELECT $1,$2,sequence,$3,$4,$5 FROM n`,w,o.ID,device,actor,raw);if err!=nil{return err};if err=logAudit(ctx,tx,w,actor,"operation.accepted",o.ID);err!=nil{return err};known[o.ID]=o}
 return tx.QueryRow(ctx,"SELECT sequence FROM workspaces WHERE id=$1",w).Scan(&cursor)
});return cursor,err}
func(p *Postgres)Pull(ctx context.Context,w string,after int64,limit int)(domain.Page,error){out:=domain.Page{Entries:[]domain.Entry{},Cursor:after};if after<0 || limit<1 || limit>200{return out,domain.ErrInvalid}
 var latest int64;err:=p.pool.QueryRow(ctx,"SELECT sequence FROM workspaces WHERE id=$1",w).Scan(&latest);if errors.Is(err,pgx.ErrNoRows){if after!=0{return out,domain.ErrInvalid};return out,nil};if err!=nil{return out,err};if after>latest{return out,domain.ErrInvalid}
 rows,err:=p.pool.Query(ctx,"SELECT sequence,device::text,actor,created,content FROM operations WHERE workspace=$1 AND sequence>$2 ORDER BY sequence LIMIT $3",w,after,limit+1);if err!=nil{return out,err};defer rows.Close()
 for rows.Next(){var e domain.Entry;var raw []byte;if err=rows.Scan(&e.Sequence,&e.Device,&e.Actor,&e.Created,&raw);err!=nil{return out,err};if len(out.Entries)==limit{out.More=true;break};if err=json.Unmarshal(raw,&e.Operation);err!=nil{return out,err};out.Entries=append(out.Entries,e);out.Cursor=e.Sequence};return out,rows.Err()
}
func(p *Postgres)Audit(ctx context.Context,w string,after int64,limit int)([]domain.Audit,error){if after<0 || limit<1 || limit>200{return nil,domain.ErrInvalid};rows,err:=p.pool.Query(ctx,"SELECT sequence,actor,action,target,created FROM audit_events WHERE workspace=$1 AND sequence>$2 ORDER BY sequence LIMIT $3",w,after,limit);if err!=nil{return nil,err};defer rows.Close();out:=[]domain.Audit{};for rows.Next(){var a domain.Audit;if err=rows.Scan(&a.Sequence,&a.Actor,&a.Action,&a.Target,&a.Created);err!=nil{return nil,err};out=append(out,a)};return out,rows.Err()}
