import os
from psycopg2 import connect

class BuildQML:
    """
    To generate QML file fractions used as palette inputs of a final QML raster style.
    The approach is to use a previous QGIS file and produce the palette entries based on
    each vector data table used to create PRODES raster files.
    """

    def __init__(self):
        # fixed color to forest used by default background for biome border
        self.forest=lambda:["#308703"]
        # the table name patterns to select an appropriate color palette 
        self.TABLE_NAMES=["no_forest","hydrography","accumulated","yearly","residual","cloud"]
        # fixed color to hydrography
        self.hydrography=lambda hm:["#0513b1"]
        # fixed color to non forest
        self.no_forest=lambda hm:["#f213f9"]
        # fixed color to cloud
        self.cloud=lambda hm:["#37fef4"]
        # used to get palette for accumulated deforestations
        self.accumulated=lambda hm:self.__yellow()
        # used to get palette for yearly deforestations
        self.yearly=lambda hm:self.__yellow(how_many=hm)
        # used to get palette for residual deforestations
        self.residual=lambda hm:self.__red(how_many=hm)
        # the location to store the QML file fractions
        self.DATA_DIR=os.getenv("DATA_DIR")
        # the reference table name
        self.TB_NAME=os.getenv("TB_NAME")
        # the connection string to database
        self.PG_CONN=os.getenv("PG_CONN")

    def __yellow(self, how_many=1):
        """
        Used to produce up to 57 yeallow variations as:
         - 19 variations of yellow only increase blue step(10) [0-190] (red=255 and green=255);
         - 15 variations of yellow decrease 20 of green and increase blue step(10) [0-150] (red=255 and green=235);
         - 13 variations of yellow decrease 20 of green and increase blue step(10) [0-130] (red=255 and green=215);
         - 10 variations of yellow decrease 20 of green and increase blue step(10) [0-100] (red=255 and green=195);

         Usually to style the deforestations.
        """
        # the limit of this function
        if how_many>57:
            raise Exception(f"Yellow variations were exceeded by {how_many-57} units. The maximum is 57 units.")
        r=255 # no change
        g=255
        b=0
        step=lambda c: c+10
        color_list=[]
        while(len(color_list)<how_many):
            color_list.append('#{0:02x}{1:02x}{2:02x}'.format(r,g,b))
            if len(color_list)<19:
                b=step(b)
            elif len(color_list)<34:
                g=235
                b=0 if len(color_list)==19 else step(b)
            elif len(color_list)<47:
                g=215
                b=0 if len(color_list)==34 else step(b)
            elif len(color_list)<57:
                g=195
                b=0 if len(color_list)==47 else step(b)

        return color_list
    
    def __red(self, how_many=1):
        """
        Used to produce up to 120 red variations as:
         - 120 variations of red increase green step(10) [0-120] for each increase blue by step(10) (red=255);

         Usually to style the residual.
        """
        # the limit of this function
        if how_many>120:
            raise Exception(f"Red variations were exceeded by {how_many-120} units. The maximum is 120 units.")
        r=255 # no change
        g=0
        b=0
        step=lambda c: c+10
        color_list=[]
        while(len(color_list)<how_many):
            while(b<=100):
                g=step(g)
                color_list.append('#{0:02x}{1:02x}{2:02x}'.format(r,g,b))
                if g==120:
                    g=0
                    b=step(b)

        return color_list

    def __get_colors(self, size):
        """
        Select an appropriate color palette based on the input table name.

        size is the number of colors is necessary to build the palette
        """
        for tb in self.TABLE_NAMES:
            if tb in self.TB_NAME:
                #return locals()[tb](size)
                aFunc=getattr(self, tb)
                return aFunc(size)
        # if search ends without colors, use the forest as default
        return self.forest()


    def __get_palette_fraction(self):
        """
        Used to get each class number and name, get new colors, and generate the palette entries.
        """
        items=[]
        sql=f"SELECT class_number, class_name FROM public.burn_{self.TB_NAME} GROUP BY 1,2 ORDER BY 1 ASC"
        class_data=self.__execute_sql(sql)
        colors=self.__get_colors(len(class_data))
        c=0
        for cdata in class_data:
            class_number=cdata[0]
            class_name=cdata[1]
            color=colors[c]
            c+=1
            items.append(f"<paletteEntry color=\"{color}\" label=\"{class_number} {class_name}\" value=\"{class_number}\" alpha=\"255\"/>")

        return "\n".join(items)

    def __execute_sql(self, sql: str):
        curr = None
        conn = None
        try:
            conn = connect(self.PG_CONN)
            curr = conn.cursor()
            curr.execute(sql)
            rows = curr.fetchall()
            return rows if rows else None
        except Exception as e:
            raise e
        finally:
            if(not conn.closed): conn.close()

    def buildAndSaveFile(self):
        try:
            if os.path.isdir(self.DATA_DIR):
                path_dir=f"{self.DATA_DIR}"
                file_name=f"{self.TB_NAME}.sfl"
                with open(os.path.join(path_dir,file_name), "w") as file_sfl:
                    file_sfl.write(self.__get_palette_fraction())
        except Exception as e:
            print(f"Failure on store QML fragment.{e}")
        finally:
            print(f"Store QML fragment: {file_name}")

        

qml = BuildQML()
qml.buildAndSaveFile()