from glob import glob
from urllib.request import urlopen
from pandas import pandas as pd

daty = []
dni = []
miesiace = []
lata = []
data = ''
miesiac = ''
dzien = ''
#for mm in range(1, 13):
for mm in range(1, 5):
    if(mm<10):
       miesiac = '0' + str(mm)
    else: 
        miesiac = str(mm)
    for dd in range(1, 32):
        if(dd<10):
            dzien = '0' + str(dd)
        else:
            dzien = str(dd)
        rok = '2020'
        data = miesiac + '-' + dzien + '-' + rok
        daty.append(data)
        dni.append(dzien)
        miesiace.append(miesiac)
        lata.append(rok)

#for mm in range(1, 13):
#    if(mm<10):
#       miesiac = '0' + str(mm)
#    else: 
#        miesiac = str(mm)
#    for dd in range(1, 32):
#        if(dd<10):
#            dzien = '0' + str(dd)
#        else:
#            dzien = str(dd)
#        rok = '2021'
#        data = miesiac + '-' + dzien + '-' + rok
#        daty.append(data)
#        dni.append(dzien)
#        miesiace.append(miesiac)
#        lata.append(rok)

pierwszy = 0

def rodzajZapisu(df, p):
    if p == 0:
        df.to_csv('InitialDataCOVID-19.csv', mode='a', header=True)
        p = 1
    else:
        df.to_csv('InitialDataCOVID-19.csv', mode='a', header=False)
    return p

def rodzajOdczytu(url, d, m, r):
    intD = int(d)
    intM = int(m)
    intR = int(r)
    if intR == 2020:
        if intM < 3:
            df = pd.read_csv(url, usecols=['Country/Region', 'Last Update', 'Confirmed', 'Deaths', 'Recovered'])
            df["Active"] = ''
            return df
        else:
            if intM == 3:
                if intD > 21:
                    return pd.read_csv(url, usecols=['Country_Region', 'Last_Update', 'Confirmed', 'Deaths', 'Recovered', 'Active'])
                else:
                    df = pd.read_csv(url, usecols=['Country/Region', 'Last Update', 'Confirmed', 'Deaths', 'Recovered'])
                    df["Active"] = ''
                    return df
            else:
                return pd.read_csv(url, usecols=['Country_Region', 'Last_Update', 'Confirmed', 'Deaths', 'Recovered', 'Active'])
    else:
        return pd.read_csv(url, usecols=['Country_Region', 'Last_Update', 'Confirmed', 'Deaths', 'Recovered', 'Active'])

def find_bad_qn(data, p, d, m, r):
    try:
        print(m + '-' + d + '-' + r)
        url = 'https://raw.githubusercontent.com/CSSEGISandData/COVID-19/master/csse_covid_19_data/csse_covid_19_daily_reports/' + data + '.csv'
        urlopen(url)
        dataframes = rodzajOdczytu(url, d, m, r)
        df = pd.DataFrame(dataframes)
        p = rodzajZapisu(df, p)
        print('!')
        return p
    except:
        print('.')
        return p
        pass

print("Please Wait... it will take some time")

dni.reverse()
miesiace.reverse()
lata.reverse()

for idx, f in enumerate(reversed(daty)):
    pierwszy = find_bad_qn(f, pierwszy, dni[idx], miesiace[idx], lata[idx])