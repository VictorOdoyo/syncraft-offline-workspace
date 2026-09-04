package store

import (
 "context"
 "os"
 "testing"
 "github.com/VictorOdoyo/syncraft-offline-workspace/internal/domain"
)
func TestPostgresContract(t *testing.T){url:=os.Getenv("TEST_DATABASE_URL");if url==""{t.Skip("TEST_DATABASE_URL requires disposable PostgreSQL")};p,err:=OpenPostgres(context.Background(),url);if err!=nil{t.Fatal(err)};defer p.Close();contract(t,p)}
func TestPostgresAttachmentIsolation(t *testing.T){url:=os.Getenv("TEST_DATABASE_URL");if url==""{t.Skip("TEST_DATABASE_URL requires disposable PostgreSQL")};ctx:=context.Background();p,err:=OpenPostgres(ctx,url);if err!=nil{t.Fatal(err)};defer p.Close();a:=domain.Attachment{ID:uid(201),Record:uid(202),Name:"inspection.txt",Type:"text/plain",SHA256:"fixture",Data:[]byte("observed")};if err=p.PutAttachment(ctx,"attachment-test","author",a);err!=nil{t.Fatal(err)};got,err:=p.GetAttachment(ctx,"attachment-test",a.ID);if err!=nil || string(got.Data)!="observed"{t.Fatal(got,err)};if _,err=p.GetAttachment(ctx,"other",a.ID);err==nil{t.Fatal("workspace leak")}}
