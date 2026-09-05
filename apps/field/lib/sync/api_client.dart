import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  final int status;final String message;
  ApiFailure(this.status,this.message);
  @override String toString()=>message;
}
class ApiClient {
  final Uri base;final http.Client transport;
  String? token;String? device;
  ApiClient(String endpoint,{http.Client? client}):base=Uri.parse(endpoint),transport=client??http.Client(){
    if(!['http','https'].contains(base.scheme)||base.host.isEmpty||base.userInfo.isNotEmpty||base.hasQuery||base.hasFragment){throw const FormatException('Invalid API address');}
    if(base.scheme!='https'&&!['127.0.0.1','localhost','10.0.2.2'].contains(base.host)){throw const FormatException('Remote servers require HTTPS');}
  }
  Map<String,String> get headers=>{'Content-Type':'application/json',if(token!=null)'Authorization':'Bearer $token',if(device!=null)'X-Device-ID':device!};
  Uri uri(String path)=>base.resolve(path);
  Future<dynamic> get(String path)async=>_decode(await transport.get(uri(path),headers:headers).timeout(const Duration(seconds:20)));
  Future<dynamic> post(String path,Object body)async=>_decode(await transport.post(uri(path),headers:headers,body:jsonEncode(body)).timeout(const Duration(seconds:20)));
  dynamic _decode(http.Response response){
    final body=jsonDecode(response.body);
    if(response.statusCode<200||response.statusCode>=300){throw ApiFailure(response.statusCode,body is Map ? body['error']?.toString()??'Request failed':'Request failed');}
    return body;
  }
  Future<Map<String,dynamic>> upload(String id,String record,String name,String media,Uint8List bytes)async=>
    Map<String,dynamic>.from(_decode(await transport.post(uri('/api/v1/attachments/$id'),headers:{...headers,'Content-Type':media,'X-Record-ID':record,'X-Filename':Uri.encodeQueryComponent(name)},body:bytes).timeout(const Duration(seconds:30))) as Map);
  Future<Uint8List> download(String id)async{
    final response=await transport.get(uri('/api/v1/attachments/$id'),headers:headers).timeout(const Duration(seconds:30));
    if(response.statusCode!=200){_decode(response);}
    return response.bodyBytes;
  }
  void close()=>transport.close();
}
