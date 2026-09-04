package auth

import (
 "errors"
 "time"
 "github.com/golang-jwt/jwt/v5"
 "golang.org/x/crypto/bcrypt"
)
type User struct{PasswordHash string `json:"password_hash"`;Workspace string `json:"workspace"`;Role string `json:"role"`}
type Claims struct{Workspace string `json:"workspace"`;Role string `json:"role"`;jwt.RegisteredClaims}
type Service struct{Secret []byte;Users map[string]User}
func(s *Service)Login(name,password string)(string,error){u,ok:=s.Users[name];if !ok { _=bcrypt.CompareHashAndPassword([]byte("$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy"),[]byte(password));return "",errors.New("invalid credentials")};if bcrypt.CompareHashAndPassword([]byte(u.PasswordHash),[]byte(password))!=nil{return "",errors.New("invalid credentials")}
 now:=time.Now();c:=Claims{Workspace:u.Workspace,Role:u.Role,RegisteredClaims:jwt.RegisteredClaims{Subject:name,Issuer:"syncraft",Audience:jwt.ClaimStrings{"syncraft-field"},IssuedAt:jwt.NewNumericDate(now),ExpiresAt:jwt.NewNumericDate(now.Add(time.Hour))}}
 return jwt.NewWithClaims(jwt.SigningMethodHS256,c).SignedString(s.Secret)
}
func(s *Service)Verify(token string)(Claims,error){var c Claims;_,err:=jwt.ParseWithClaims(token,&c,func(t *jwt.Token)(any,error){return s.Secret,nil},jwt.WithValidMethods([]string{"HS256"}),jwt.WithIssuer("syncraft"),jwt.WithAudience("syncraft-field"),jwt.WithExpirationRequired());if err!=nil{return c,err};u,ok:=s.Users[c.Subject];if !ok || c.Workspace!=u.Workspace || c.Role!=u.Role{return c,errors.New("identity no longer authorized")};return c,nil}
func DemoUsers()map[string]User{hash,_:=bcrypt.GenerateFromPassword([]byte("local-demo"),bcrypt.DefaultCost);out:=map[string]User{};for name,role:=range map[string]string{"inspector":"editor","reviewer":"editor","observer":"viewer","admin":"admin"}{out[name]=User{string(hash),"demo",role}};return out}
