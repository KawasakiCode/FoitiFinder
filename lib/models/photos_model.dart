//Grabs data of a photo of the user (NOT pfp but photo that gets displayed 
//in the users card)

//displayOrder is used to keep the photos in the same order as the user uploaded them
//Used to load other user's photos in the card stack or the users cards
//in edit profile page

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