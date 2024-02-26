#!/bin/bash
# Autor: Tristan MICHELENA
# Date: 19/03/2023

# This code uses API to put photos from a folder in a photo server online.
# It also removes the photos which are not in the folder anymore.
# It searchs the description with another API to add it to the photo.

# User's informations.
token="token"
user="user"
password="password"
key_pexels="key"

# If the folder is properly mounted.
if mount | grep /home/datasource > /dev/null; then
        echo "The shared folder is properly mounted."

        # Connexion to the server.
        curl -X POST -H "Authorization:$token" \
        -H 'Content-Type:application/json' -H'Accept:application/json' \
        -d"{"\"username\"": "\"$user\"", "\"password\"": "\"$password\""}" \
        https://"LINK TO MY PHOTOSERVER"/api/Session::login

        # Get the id of the album associated to the token.
        id_album=$(curl -X POST -H "Authorization:$token" \
        -H 'Content-Type:application/json' -H'Accept:application/json' \
        https://"LINK TO MY PHOTOSERVER"/api/Albums::get | jq ".albums[] | .id")
        echo "The ID of your album is: $id_album"

        # Get the name of the photos in the album.
        photos_alb=$(curl -X POST -H "Authorization:$token" \
        -H 'Content-Type:application/json' -H 'Accept:application/json' \
        -d"{"\"albumID\"": $id_album}" \
        https://"LINK TO MY PHOTOSERVER"/api/Album::get | jq '.photos[] | .title')

        # Cleaning the picture name.
        photos_alb_flt=$(echo $photos_alb | tr -d '"')

        echo "Treatment in progress..."
        # For each file with the .jpg extension in the share folder.
        for photo_fold in /home/datasource/*.jpg ; do
                # Cleaning the picture name.
                photo_fold_flt="$(echo ${photo_fold##*/} | cut -d'.' -f 1)"

                # The photo has not be found yet.
                photo_in_alb=0

                # If the picture in the folder find the associated
                # picture in the album.
                if echo "$photos_alb_flt" | grep -qw "$photo_fold_flt" ; then
                        # The photo has been found.
                        photo_in_alb=1
                fi

                # If the photo has not been found.
                if ! ((photo_in_alb)) ; then
                        # Add the photo in the album and get its ID.
                        id_photo_add=$(curl -X POST -H "Authorization:$token" \
                        -H 'Content-Type:multipart/form-data' -H 'Accept:application/json' \
                        -F "albumID=$id_album" \
                        -F "file=@/home/datasource/$photo_fold_flt.jpg"\
                        https://"LINK TO MY PHOTOSERVER"/api/Photo::add | jq ".id")

                        # Launch the program to get the associated color.
                        color=$(/home/datasource/getColor.py \
                        /home/datasource/$photo_fold_flt.jpg)
                        #Replace the comma by the tag structure.
                        color_flt=$(echo "$color" | sed 's/,/", "/g' | sed 's/^/"/;s/$/"/')

                        # Inject the tags.
                        curl -X POST -H "Authorization:$token" \
                        -H 'Content-Type:application/json' -H 'Accept:application/json' \
                        -d"{"\"shall_override\"":true, "\"photoIDs\"":[$id_photo_add], "\"tags\"":[$color_flt]}" \
                        https://"LINK TO MY PHOTOSERVER"/api/Photo::setTags

                        # Get the description. (Want more)
                        photo_descript=$(curl -H "Authorization: $key_pexels" \
                        "https://api.pexels.com/v1/photos/$photo_fold_flt" | jq ".alt")

                        # Inject the description. (Want more)
                        curl -X POST -H "Authorization:$token" \
                        -H 'Content-Type:application/json' -H 'Accept:application/json' \
                        -d"{"\"shall_override\"":true, "\"photoID\"":$id_photo_add, "\"description\"":$photo_descript}" \
                        https://"LINK TO MY PHOTOSERVER"/api/Photo::setDescription

                fi
                # Remove the treated photo name from the list. (Deletion)
                photos_alb_flt=${photos_alb_flt/$photo_fold_flt/}
        done
        # Remove the double space. (Deletion)
        photos_alb_flt=$(echo "$photos_alb_flt" | tr -s ' ')
        # If the list is not empty. (Deletion)
        if [ "$photos_alb_flt" != " " ] ; then
                # Print the name of the photo(s) to remove. (Deletion)
                echo "Photo(s) to delete: $photos_alb_flt ."
                # Get the list of all the photos' title and id. (Deletion)
                photos_id_name=$(curl -X POST -H "Authorization:$token" \
                -H 'Content-Type:application/json' -H 'Accept:application/json' \
                -d"{"\"albumID\"": $id_album}" \
                https://"LINK TO MY PHOTOSERVER"/api/Album::get | jq '.photos[] | .id,.title')
                photos_id_name=$(echo $photos_id_name | tr -d '"' )
                # For each photo to delete. (Deletion)
                for photos_remove in $photos_alb_flt ; do
                        photo_rm_id=""
                        # For each photo in the list. (Deletion)
                        for photo_present in $photos_id_name ; do
                                # If the name of the photo is found. (Deletion)
                                if [ "$photo_present" == "$photos_remove" ] ; then
                                        # Leave the loop. (Deletion)
                                        break
                                fi
                        # Get the previous value which is the ID. (Deletion)
                        photo_rm_id=$photo_present
                        done
                        # Remove the photo in the album. (Deletion)
                        curl -X POST -H "Authorization:$token" \
                        -H 'Content-Type:application/json' -H 'Accept:application/json' \
                        -d"{"\"photoIDs\"":["\"$photo_rm_id\""]}" \
                        https://"LINK TO MY PHOTOSERVER"/api/Photo::delete
                done
                # Print the action is done. (Deletion)
                echo "Photo(s) deleted."
        else
                echo "No photo to delete."
        fi

	  #Logout
	  curl -X POST -H "Authorization:$token" \
	  -H 'Content-Type:application/json' -H'Accept:application/json' \
	  -d"{"\"username\"": "\"$user\"", "\"password\"": "\"$password\""}" \
	  https://"LINK TO MY PHOTOSERVER"/api/Session::logout

        exit 1
else
        echo "The share folder is not mounted."
        exit 0
fi


