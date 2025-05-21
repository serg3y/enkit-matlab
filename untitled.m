% curl -X POST https://auth.tesla.com/oauth2/v3/token \
%   -H "Content-Type: application/json" \
%   -d '{
%     "grant_type": "refresh_token",
%     "client_id": "ownerapi",
%     "refresh_token": "YOUR_REFRESH_TOKEN",
%     "scope": "openid email offline_access"
%   }'

refresh_token = 'eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjI5Skh4dlVBVVFfbDlBVXFhcHBrV2dLRDhRRSJ9.eyJpc3MiOiJodHRwczovL2F1dGgudGVzbGEuY29tL29hdXRoMi92MyIsImF1ZCI6Imh0dHBzOi8vYXV0aC50ZXNsYS5jb20vb2F1dGgyL3YzL3Rva2VuIiwiaWF0IjoxNzQ2ODgwNjg0LCJzY3AiOlsib3BlbmlkIiwib2ZmbGluZV9hY2Nlc3MiXSwib3VfY29kZSI6Ik5BIiwiZGF0YSI6eyJ2IjoiMSIsImF1ZCI6Imh0dHBzOi8vb3duZXItYXBpLnRlc2xhbW90b3JzLmNvbS8iLCJzdWIiOiIxNzEwZjYwYS01ZmJhLTRmNWUtYjY1Yi00OWU4MTk0MWE3OWEiLCJzY3AiOlsib3BlbmlkIiwiZW1haWwiLCJvZmZsaW5lX2FjY2VzcyJdLCJhenAiOiJvd25lcmFwaSIsImFtciI6WyJwd2QiLCJwaG9uZTJmYSJdLCJhdXRoX3RpbWUiOjE3NDY4ODA2Njd9fQ.IrnXE1kZ2ilZvmWJmoQtqXI7Z6MPnAqlho00tU5llCXTg2uJHYrTh3BB7x_D5Io6_OfKJl5JP6_wwH1xcVbzhPey2Ts6_gnnmgY7MSNQeRHsDvEiEfso0YnnyzLIK7C2khgte4n1KqoRWdhTT5rnYC_jtKoqnxWzR51DgifWYtiJIYvqot0jCcKEMvdoYG7NNDDAmxv66uaGtDVWuAUIMFUzcd7T-D-rIcbmLQgs2Uphnq5tkpKlCGDY8M7WqFMIi3FrZxFP6p89dgtgWJ2TnyRmeCBWv-CN8mqg6fKJBxRkQslxc9FC04uQxLeI9qOBslkT9z5nR5vy2SPE3Yxhfw';
[err, json] = system(['curl -sS -X POST https://auth.tesla.com/oauth2/v3/token -H "Content-Type: application/json" -d "{\"grant_type\":\"refresh_token\",\"client_id\":\"ownerapi\",\"refresh_token\":\"' refresh_token '\",\"scope\":\"openid email offline_access\"}"']);

data = jsondecode(json)
data.expires_at = datetime + seconds(data.expires_in)
