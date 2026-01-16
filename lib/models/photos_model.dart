class PhotosModel {
  final int userId;
  final String photoUrl;
  final int displayOrder;

  PhotosModel({
    required this.userId,
    required this.photoUrl,
    required this.displayOrder,
  });

  factory PhotosModel.fromJson(Map<String, dynamic> json)  {
    return PhotosModel(  
      userId: json['user_id'],
      photoUrl: json['photo_url'],
      displayOrder: json['display_order']
    );
  }
}