//Turning the stored birthday into the age the UI shows.
//
//UserModel holds a birthday, not an age: an age integer is only correct on the
//day it was written, and silently wrong every day after. Everything that wants
//to display a number derives it here.
//
//The backend does the same on its side (backend/ages.py) for people OTHER than
//the signed-in user - cards and likers still arrive with a plain `age` integer
//already computed, so only the owner's own profile needs this.

//Whole years since [birthday], or null when it was never set.
int? ageFromBirthday(DateTime? birthday) {
  if (birthday == null) return null;

  final now = DateTime.now();
  //one year less when this year's birthday hasn't come round yet
  final hadBirthdayThisYear = now.month > birthday.month ||
      (now.month == birthday.month && now.day >= birthday.day);

  return now.year - birthday.year - (hadBirthdayThisYear ? 0 : 1);
}

//The birthday of someone turning [years] old today.
//
//Used to bound a date picker: passing 18 gives the LATEST birthday that still
//makes someone 18, so an under-age date cannot be picked in the first place.
DateTime birthdayForAge(int years) {
  final now = DateTime.now();
  return DateTime(now.year - years, now.month, now.day);
}
