# BITCOIN - Web Monitor
## Golang based Bitcoin monitor


**Table of content:**

- [About Project](#item-one)
- [Prerequisites](#item-two)
- [Implementation](#item-three)
- [What can be done better](#item-four)
- [Final words](#item-five)

<!-- headings -->
<a id="item-one"></a>
### About Bitcoin Monitor

Project Bitcoin Monitor is a microservices implementation of an application that can provide a realtime monitor for the Bitcoin values. It is implemented in Golang using the net/http library for implementing the web server connectivity.
By using a go routine that is running in parallel with the main function, the Bitcoin value is automatically update at specific time interval, default of 10 seconds, and based on the iteration value (default is 3 times), it calculate the average value. 
The application is deployed as a container, during the build process the code is compiled and the tagged image is pushed in a private ACR Registry. Also, the image will automatically expose the port 8080.

<a id="item-two"></a>
### Prerequisites
- Azure CLI
- Docker Engine
- kubelet
  

<a id="item-three"></a>
### Implementation
Second item content goes here

<a id="item-four"></a>
### What can be done better
- Adding TLS support to Nginx Ingress controller by appending the TLS section in Ingress manifest
- Implementing the net/http Listener in goroutines to adapt to a higher number of requests
- Possible bug/race condition avoiding at the changing of the index.html file. If there is a http request in same time with an update operation it can trigger an error.
- Frontend workout
- Using Go template implementation for improving the Web Frontend
- Save data localy to have an historical pattern

<a id="item-five"></a>
### Final words
Second item content goes here
