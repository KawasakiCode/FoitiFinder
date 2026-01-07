class PhotosModel {
  final String uid;
  final String photoUrl;
  final int displayOrder;

  PhotosModel({
    required this.uid,
    required this.photoUrl,
    required this.displayOrder,
  });

  factory PhotosModel.fromJson(Map<String, dynamic> json)  {
    return PhotosModel(  
      uid: json['firebase_token'],
      photoUrl: json['photos_url'],
      displayOrder: json['display_order']
    );
  }
}