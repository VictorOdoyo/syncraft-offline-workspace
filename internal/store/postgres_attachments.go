package store

import (
 "context"
 "errors"
 "github.com/jackc/pgx/v5"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
)
func(p *Postgres)PutAttachment(ctx context.Context,w,actor string,a domain.Attachment)error{return p.write(ctx,w,func(tx pgx.Tx)error{
 var hash,record,name,media string;err:=tx.QueryRow(ctx,"SELECT sha256,record::text,name,media_type FROM attachments WHERE workspace=$1 AND id=$2",w,a.ID).Scan(&hash,&record,&name,&media)
 if err==nil{if hash!=a.SHA256 || record!=a.Record || name!=a.Name || media!=a.Type{return domain.ErrConflict};return nil};if !errors.Is(err,pgx.ErrNoRows){return err}
 if _,err=tx.Exec(ctx,"INSERT INTO attachments(workspace,id,record,name,media_type,sha256,content) VALUES($1,$2,$3,$4,$5,$6,$7)",w,a.ID,a.Record,a.Name,a.Type,a.SHA256,a.Data);err!=nil{return err};return logAudit(ctx,tx,w,actor,"attachment.stored",a.ID)
})}
func(p *Postgres)GetAttachment(ctx context.Context,w,id string)(domain.Attachment,error){a:=domain.Attachment{ID:id};err:=p.pool.QueryRow(ctx,"SELECT record::text,name,media_type,sha256,content FROM attachments WHERE workspace=$1 AND id=$2",w,id).Scan(&a.Record,&a.Name,&a.Type,&a.SHA256,&a.Data);a.Size=len(a.Data);if errors.Is(err,pgx.ErrNoRows){err=domain.ErrNotFound};return a,err}
func(p *Postgres)Attachments(ctx context.Context,w,record string)([]domain.Attachment,error){rows,err:=p.pool.Query(ctx,"SELECT id::text,record::text,name,media_type,sha256,octet_length(content) FROM attachments WHERE workspace=$1 AND record=$2 ORDER BY id LIMIT 500",w,record);if err!=nil{return nil,err};defer rows.Close();out:=[]domain.Attachment{};for rows.Next(){var a domain.Attachment;if err=rows.Scan(&a.ID,&a.Record,&a.Name,&a.Type,&a.SHA256,&a.Size);err!=nil{return nil,err};out=append(out,a)};return out,rows.Err()}
