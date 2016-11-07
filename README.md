# hubot-service-now
A hubot script to perform record lookups to a Service Now Instance

## Installation
Add `hubot-service-now` to your `external-scripts.json` file:
```json
"dependencies": {
  "hubot": "^2.19.0",
  "hubot-redis-brain": "0.0.3",
  "hubot-scripts": "^2.17.2",
  "hubot-service-now": "^1.0.0"
}
```

Install the package: `npm install hubot-service-now --save`

## Sample Interaction
```
user1>> hubot snow INC0000001
hubot>>
Found INC0000001:
Short Description: The hamburger has been stolen
Assigned to: Hamburger Recovery
Opened By: Ian Ward
Opened At: 1970-01-01 00:00:00
Priority: 1
State: Work in Progress
```

## Implicit/Explicit Listen Toggle
By default, hubot will only listen for explicit requests (a channel/group mention or direct message, plus the trigger phrase: sn, snow, service now). However, you can optionally enable implicit operation on a per-channel basis. This relies on persistence via a hubot brain (hubot-redis-brain is the only one tested).
This per-channel toggle is triggered by the trigger phrase (case insensitive: sn, snow, service now), plus "listen".

A sample interaction is as follows:
```
user1>> INC0000001
user1>> Bill, please work on INC0000001
user1>> hubot service now listen
hubot>> I will listen for Service Now
user1>> INC0000001
hubot>>
Found INC0000001:
Short Description: The hamburger has been stolen
Assigned to: Hamburger Recovery
Opened By: Ian Ward
Opened At: 1970-01-01 00:00:00
Priority: 1
State: Work in Progress
user1>> Bob, please work on INC0000002 for me.
hubot>>
Found INC0000002:
Short Description: The hamburger recovery team has gotten lost in a health foods store
Assigned to: Hamburger Recovery Recovery
Opened By: Ian Ward
Opened At: 1970-01-02 00:00:00
Priority: 1
State: Work in Progress
user1>> hubot service now listen
hubot>> I won't listen for Service Now
user1>> INC0000001
<no reponse>
```
