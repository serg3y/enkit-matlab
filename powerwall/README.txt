To access data from Tesla.com, you need an "access_token".
This token expires in 8 hours but can be refreshed using a "refresh_token".
The "refresh_token" also expires, but only after 45 days of inactivity.
To get and use a refresh_token:
1. Visit a third-party helper, eg https://www.myteslamate.com/tesla-token
2. Save your refresh_token to: .\my_refresh_token.txt
3. Run my_access_token.m to generate a new access token and cache it to: .\my_access_token.json
