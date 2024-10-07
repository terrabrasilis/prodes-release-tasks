import os
from psycopg2 import connect

class BuildQML:
    """
    To generate QML file fractions used as palette inputs of a final QML raster style.
    The approach is to use a previous QGIS file and produce the palette entries based on
    each vector data table used to create PRODES raster files.
    """

    def __init__(self, color_step=15):
        # the default number used to increase RGB to produce color variations
        self.color_step=color_step
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
        self.accumulated=lambda hm:["#ffff00"]
        # used to get palette for yearly deforestations
        self.yearly=lambda hm:self.__yellow(how_many=hm)
        # used to get palette for residual deforestations
        self.residual=lambda hm:self.__red(how_many=hm)
        # Used to increase number in color_step. The color_step can be divided by a factor.
        self.increase=lambda c,f=1: c+int(self.color_step/f)
        # Used to decrease the number in color_step. The color_step can be divided by a factor.
        self.decrease=lambda c,f=1: c-int(self.color_step/f)
        # the location to store the QML file fractions
        self.DATA_DIR=os.getenv("DATA_DIR")
        # the reference table name
        self.TB_NAME=os.getenv("TB_NAME")
        # the connection string to database
        self.PG_CONN=os.getenv("PG_CONN")

    def __yellow(self, how_many=1):
        """
        Used to produce yellow variations.
        
        Yellow variations are created by increasing blue using color_step.
        When blue is at the maximum for the color channel, upper_b, it returns to zero and
        green decreases by color_step and blue increases by color_step again.

        Usually to style the deforestations.
        """
        r=255 # no change
        # limits
        upper_b=190
        upper_g=240
        lower_g=195
        g=lower_g
        b=0
        color_list=[]
        while(len(color_list)<how_many):
            color_list.append('#{0:02x}{1:02x}{2:02x}'.format(r,g,b))
            b=self.increase(b)
            b=b if b<=upper_b else 0
            upper_b=int(upper_b*0.7) if b==0 else upper_b
            g=self.increase(g,3) if (len(color_list)%3)==0 else g
            g=g if g<=upper_g else lower_g

        return color_list
    
    def __red(self, how_many=1):
        """
        Used to produce red variations.
        Red variations are created by increasing green in color_step for each increase in blue in color_step and setting red = 255.
        Usually to style the residual.
        """
        # limits
        upper_r=255
        upper_g=150
        upper_b=90
        lower_r=220
        lower_g=20
        lower_b=0
        r=upper_r
        g=upper_g
        b=lower_b
        color_list=[]
        step=lambda s: (len(color_list)%s)==0
        while(len(color_list)<how_many):
            color_list.append('#{0:02x}{1:02x}{2:02x}'.format(r,g,b))
            # change red
            r=self.decrease(r) if step(3) else r
            r=r if r>=lower_r else upper_r
            upper_r=int(upper_r*0.7) if step(3) and r==upper_r else upper_r

            # change green
            g=self.decrease(g) if step(2) else g
            g=g if g>=lower_g else upper_g
            upper_g=int(upper_g*0.7) if step(2) and g==upper_g else upper_g
            
            # change blue
            b=self.increase(b)
            b=b if b<=upper_b else lower_b
            upper_b=int(upper_b*0.7) if b==lower_b else upper_b

        return color_list

    def __get_colors(self, size):
        """
        Select an appropriate color palette based on the input table name.

        size is the number of colors is necessary to build the palette
        """
        for tb in self.TABLE_NAMES:
            if tb in self.TB_NAME:
                aFunc=getattr(self, tb)
                return aFunc(size)
        # if search ends without colors, use the forest as default
        return self.forest()


    def __build_palette_fractions(self):
        """
        Used to get each class number and name, get new colors, and generate the palette entries.
        """
        qml_fraction=[]
        sld_fraction=[]
        sql=f"SELECT class_number, class_name FROM public.burn_{self.TB_NAME} GROUP BY 1,2 ORDER BY 1 ASC"
        class_data=self.__execute_sql(sql)
        colors=self.__get_colors(len(class_data))
        c=0
        for cdata in class_data:
            class_number=cdata[0]
            class_name=cdata[1]
            color=colors[c]
            c+=1
            qml_fraction.append(f"<paletteEntry color=\"{color}\" label=\"{class_number} {class_name}\" value=\"{class_number}\" alpha=\"255\"/>")
            sld_fraction.append(f"<sld:ColorMapEntry color=\"{color}\" label=\"{class_number} {class_name}\" quantity=\"{class_number}\"/>")

        return "\n".join(qml_fraction), "\n".join(sld_fraction)

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
            print(f"Failure on exec SQL into Database. Error: {e}")
            raise e
        finally:
            if(conn and not conn.closed): conn.close()

    def buildAndSaveFile(self):
        try:
            if os.path.isdir(self.DATA_DIR):
                path_dir=f"{self.DATA_DIR}"
                file_name_sfl=f"{self.TB_NAME}.sfl"
                file_name_sld=f"{self.TB_NAME}.sldf"
                qml_fraction, sld_fraction = self.__build_palette_fractions()
                with open(os.path.join(path_dir,file_name_sfl), "w") as file_sfl:
                    file_sfl.write(qml_fraction)
                with open(os.path.join(path_dir,file_name_sld), "w") as file_sld:
                    file_sld.write(sld_fraction)
        except Exception as e:
            print(f"Failure on store QML fragment.{e}")
        finally:
            print(f"Store QML fragment in: {file_name_sfl} and {file_name_sld}")

        

qml = BuildQML()
qml.buildAndSaveFile()