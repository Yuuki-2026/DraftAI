export class ServiceError extends Error {
 constructor(status,message,code='request_failed'){super(message);this.status=status;this.code=code;}
}
