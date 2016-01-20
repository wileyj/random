#include <stdio.h> 
#include <dir.h> 
#include <string.h> 
#define ALL_ATTS  (FA_DIREC | FA_ARCH) 

void walker(const char *, const char *);

void walker(const char *path, const char *findme)
{
  struct ffblk  finder;
  unsigned int  res;

  chdir(path);

  for (res = findfirst("*.*", &finder, ALL_ATTS); res == 0; res = findnext(&finder))
  {
    if (strcmp(finder.ff_name, ".") == 0) continue;   /* current dir */
    if (strcmp(finder.ff_name, "..") == 0) continue;  /* parent dir  */

    /* 
     * If its a directory, examine it
     * else compare the filename with the one we're looking for
     */
    if (finder.ff_attrib & FA_DIREC)
    {
      char newpath[MAXPATH];
      strcpy(newpath, path);
      strcat(newpath, "\\");
      strcat(newpath, finder.ff_name);
      chdir(finder.ff_name);
      walker(newpath, findme);
      chdir("..");
    }
    else
    {
      if (strcmp(finder.ff_name, findme) == 0)
      {
        printf("Found in: %s\n", path);
      }
    }
  }
}

int main(void)
{
  const char *root = "\\";
  char buf[BUFSIZ];
  
  printf ("This program will find a file on the current drive.\n"
          "Enter the name of the file to look for: ");

  fflush(stdout);  

  if (fgets(buf, sizeof(buf), stdin))
  {
    strtok(buf, "\n");  /* Remove the newline character */
    walker(root, buf);
  }
  
  return(0);
}

/*
 * Program output:
 This program will find a file on the current drive.
 Enter the name of the file to look for: MyFile.txt
 Found in: \\Temp\MySubDir
 *
 */
